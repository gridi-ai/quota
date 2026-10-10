import AppKit
import Combine
import Foundation
import QuotaCore

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var ledger = AccountLedger()
    @Published private(set) var busy: Set<UUID> = []
    @Published private(set) var messages: [UUID: String] = [:]
    @Published private(set) var claudeLoginPending: Set<UUID> = []
    @Published private(set) var claudeLoginRetryable: Set<UUID> = []
    @Published var globalError: String?
    @Published var organizations: [UUID: [ClaudeOrganization]] = [:]
    @Published var compact = UserDefaults.standard.object(forKey: "compact") as? Bool ?? true {
        didSet { if !isDemo { UserDefaults.standard.set(compact, forKey: "compact") } }
    }
    @Published var pinned = UserDefaults.standard.object(forKey: "pinned") as? Bool ?? true {
        didSet { if !isDemo { UserDefaults.standard.set(pinned, forKey: "pinned") }; onPinChanged?(pinned) }
    }
    @Published var theme = UserDefaults.standard.string(forKey: "theme") ?? "system" {
        didSet { if !isDemo { UserDefaults.standard.set(theme, forKey: "theme") }; onThemeChanged?(theme) }
    }
    @Published var filter = "all"
    @Published var language = UserDefaults.standard.string(forKey: "appLanguage") ?? "system" {
        didSet {
            var arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
            arguments["appLanguage"] = language
            UserDefaults.standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
            if !isDemo { UserDefaults.standard.set(language, forKey: "appLanguage") }
        }
    }
    @Published var menuSelections = UserDefaults.standard.dictionary(forKey: "menuSelections") as? [String: String] ?? [:] {
        didSet {
            if !isDemo { UserDefaults.standard.set(menuSelections, forKey: "menuSelections") }
        }
    }
    @Published var showAdd = false
    @Published var codexPath = UserDefaults.standard.string(forKey: "codexPath") ?? AppStore.findCodex() {
        didSet {
            if !isDemo { UserDefaults.standard.set(codexPath, forKey: "codexPath") }
            let previous = codex
            codex = [:]
            for client in previous.values { Task { await client.shutdown() } }
        }
    }
    var onPinChanged: ((Bool) -> Void)?
    var onThemeChanged: ((String) -> Void)?
    var onSettingsRequested: (() -> Void)?
    private var claude: [UUID: ClaudeSession] = [:]
    private var codex: [UUID: CodexClient] = [:]
    private var refreshTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var storageAvailable = true
    let root: URL
    let isDemo: Bool

    init(demo: Bool = false) {
        isDemo = demo
        root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Quota", isDirectory: true)
        if demo {
            loadDemo()
            return
        }
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let state = root.appendingPathComponent("accounts.json")
            if FileManager.default.fileExists(atPath: state.path) {
                ledger = try JSONDecoder().decode(AccountLedger.self, from: Data(contentsOf: state))
            }
        } catch {
            storageAvailable = false
            globalError = tr("Cannot read account data. The existing file was preserved: %@", error.localizedDescription)
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshAll() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.refreshAll() } }
        refreshAll()
    }

    var accounts: [Account] {
        ledger.accounts.filter { filter == "all" || $0.provider.rawValue == filter }
    }

    var canEditAccounts: Bool { storageAvailable && !isDemo }

    func showInMenuBar(_ account: Account) {
        menuSelections[account.provider.rawValue] = account.id.uuidString
    }

    func menuMetrics(at date: Date = Date()) -> [MenuQuota] {
        MenuQuota.metrics(
            ledger: ledger, selections: menuSelections,
            failedAccounts: Set(messages.keys), at: date
        )
    }

    func add(alias: String, provider: Provider, existingHome: String?, executablePath: String?) async throws {
        guard canEditAccounts else {
            throw UsageError.providerMessage(tr("Account changes are paused because the account file could not be read. Restore the file and reopen the app."))
        }
        let alias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !alias.isEmpty else { throw UsageError.providerMessage(tr("Enter an account alias.")) }
        var account = Account(alias: alias, provider: provider)
        if provider == .codex {
            guard let executablePath, FileManager.default.isExecutableFile(atPath: executablePath) else {
                throw UsageError.missingCLI
            }
            let requested = existingHome?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            account.codexHome = requested.isEmpty
                ? root.appendingPathComponent("codex/\(account.id.uuidString)", isDirectory: true).path
                : NSString(string: requested).expandingTildeInPath
            guard let home = account.codexHome, home.hasPrefix("/") else {
                throw UsageError.providerMessage(tr("Use an absolute path for the Codex profile."))
            }
            if ledger.accounts.contains(where: { $0.codexHome == home }) {
                throw UsageError.providerMessage(tr("This Codex profile is already connected."))
            }
            try FileManager.default.createDirectory(atPath: home, withIntermediateDirectories: true)
        }
        ledger.accounts.append(account)
        guard save() else {
            ledger.remove(account.id)
            throw UsageError.providerMessage(globalError ?? tr("Cannot save account data."))
        }
        if provider == .codex, let executablePath { codexPath = executablePath }
        showAdd = false
        if provider == .claude {
            connect(account)
        } else {
            if let existingHome, !existingHome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await refresh(account.id)
            } else {
                await loginCodex(account.id)
            }
        }
    }

    func connect(_ account: Account) {
        guard !isDemo, !busy.contains(account.id) else { return }
        if account.provider == .claude {
            do {
                try session(for: account).showLogin()
                claudeLoginPending.insert(account.id)
                claudeLoginRetryable.remove(account.id)
                messages[account.id] = tr("Sign in in your browser, then choose Enter authorization code.")
            } catch { messages[account.id] = error.localizedDescription }
        } else {
            Task { await loginCodex(account.id) }
        }
    }

    func completeClaudeLogin(_ id: UUID, code: String) async {
        guard !isDemo, !busy.contains(id),
              let account = ledger.accounts.first(where: { $0.id == id && $0.provider == .claude }) else { return }
        busy.insert(id)
        defer { busy.remove(id) }
        do {
            let snapshot = try await session(for: account).completeLogin(code: code, expectedIdentity: account.identity)
            if try ledger.apply(snapshot, to: id) {
                claudeLoginPending.remove(id)
                claudeLoginRetryable.remove(id)
                messages[id] = snapshot.limits.isEmpty ? tr("No usage limits were provided for this account.") : nil
                save()
            }
        } catch {
            if ledger.accounts.contains(where: { $0.id == id }) {
                let session = session(for: account)
                if session.didCommitLogin {
                    claudeLoginPending.remove(id)
                    claudeLoginRetryable.remove(id)
                    if let profile = session.verifiedProfile,
                       let index = ledger.accounts.firstIndex(where: { $0.id == id }) {
                        ledger.accounts[index].identity = profile.identity
                        ledger.accounts[index].organizationID = profile.organizationID
                        save()
                    }
                } else if session.hasPendingTokens {
                    claudeLoginRetryable.insert(id)
                }
                messages[id] = error.localizedDescription
            }
        }
    }

    func selectOrganization(_ id: String, for accountID: UUID, confirmedChange: Bool = false) {
        guard canEditAccounts else { return }
        Task { await refresh(accountID, organizationOverride: id, confirmedOrganizationChange: confirmedChange) }
    }

    func refreshAll() {
        guard !isDemo else { return }
        for account in ledger.accounts {
            Task { await refresh(account.id) }
        }
    }

    func refresh(_ id: UUID, organizationOverride: String? = nil, confirmedOrganizationChange: Bool = false) async {
        guard !isDemo, !busy.contains(id), !claudeLoginPending.contains(id),
              let account = ledger.accounts.first(where: { $0.id == id }) else { return }
        busy.insert(id)
        messages[id] = nil
        defer { busy.remove(id) }
        do {
            let snapshot: UsageSnapshot
            switch account.provider {
            case .codex:
                snapshot = try await client(for: account).readUsage()
            case .claude:
                switch try await session(for: account).readUsage(organizationID: organizationOverride ?? account.organizationID) {
                case .snapshot(let value): snapshot = value
                case .organizations(let choices):
                    guard ledger.accounts.contains(where: { $0.id == id }) else { return }
                    organizations[id] = choices
                    messages[id] = tr("Choose an organization to show its usage.")
                    return
                }
            }
            let applied = try confirmedOrganizationChange
                ? ledger.changeOrganization(snapshot, for: id)
                : ledger.apply(snapshot, to: id)
            if applied {
                messages[id] = snapshot.limits.isEmpty ? tr("No usage limits were provided for this account.") : nil
                organizations[id] = nil
                save()
            }
        } catch {
            guard ledger.accounts.contains(where: { $0.id == id }) else { return }
            messages[id] = error.localizedDescription
        }
    }

    private func loginCodex(_ id: UUID) async {
        guard !busy.contains(id), let account = ledger.accounts.first(where: { $0.id == id }) else { return }
        busy.insert(id)
        defer { busy.remove(id) }
        do {
            let url = try await client(for: account).startLogin()
            NSWorkspace.shared.open(url)
            messages[id] = tr("After browser sign-in, choose Check connection.")
        } catch { messages[id] = error.localizedDescription }
    }

    func remove(_ account: Account) {
        guard canEditAccounts else { return }
        ledger.remove(account.id)
        messages[account.id] = nil
        organizations[account.id] = nil
        claudeLoginPending.remove(account.id)
        claudeLoginRetryable.remove(account.id)
        claude.removeValue(forKey: account.id)?.shutdown()
        if let client = codex.removeValue(forKey: account.id) { Task { await client.shutdown() } }
        save()
    }

    func rename(_ id: UUID, alias: String) {
        let alias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canEditAccounts, !alias.isEmpty, let index = ledger.accounts.firstIndex(where: { $0.id == id }) else { return }
        ledger.accounts[index].alias = alias
        save()
    }

    private func session(for account: Account) -> ClaudeSession {
        if let session = claude[account.id] { return session }
        let session = ClaudeSession(accountID: account.id)
        claude[account.id] = session
        return session
    }

    private func client(for account: Account) throws -> CodexClient {
        if let client = codex[account.id] { return client }
        guard let home = account.codexHome, FileManager.default.isExecutableFile(atPath: codexPath) else {
            throw UsageError.missingCLI
        }
        let client = CodexClient(executablePath: codexPath, home: URL(fileURLWithPath: home))
        codex[account.id] = client
        return client
    }

    @discardableResult
    private func save() -> Bool {
        guard canEditAccounts else { return false }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(ledger).write(to: root.appendingPathComponent("accounts.json"), options: .atomic)
            return true
        } catch {
            globalError = tr("Cannot save account data: %@", error.localizedDescription)
            return false
        }
    }

    func shutdown() async {
        refreshTimer?.invalidate()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        for session in claude.values { session.shutdown() }
        for client in codex.values { await client.shutdown() }
    }

    private static func findCodex() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let paths = [home + "/.local/bin/codex", "/opt/homebrew/bin/codex", "/usr/local/bin/codex"]
        return paths.first { FileManager.default.isExecutableFile(atPath: $0) } ?? ""
    }

    private func loadDemo() {
        do {
            codexPath = "/usr/local/bin/codex"
            ledger = CommandLine.arguments.contains("--demo-empty") ? AccountLedger() : try DemoData.ledger()
            if CommandLine.arguments.contains("--demo-oauth"),
               let account = ledger.accounts.first(where: { $0.provider == .claude }) {
                claudeLoginPending.insert(account.id)
                messages[account.id] = tr("Sign in in your browser, then choose Enter authorization code.")
            }
        }
        catch { globalError = error.localizedDescription }
    }
}
