import SwiftUI
import AppKit
import QuotaCore

enum Palette {
    static func muted(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.725, green: 0.733, blue: 0.682) : Color(red: 0.400, green: 0.412, blue: 0.369)
    }
    static func paper(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.153, green: 0.153, blue: 0.133) : Color(red: 1, green: 0.992, blue: 0.961)
    }
    static func quota(_ remaining: Double, _ scheme: ColorScheme) -> Color {
        if remaining == 0 {
            return scheme == .dark ? Color(red: 0.933, green: 0.635, blue: 0.588) : Color(red: 0.659, green: 0.267, blue: 0.212)
        }
        if remaining <= 20 {
            return scheme == .dark ? Color(red: 0.886, green: 0.722, blue: 0.439) : Color(red: 0.588, green: 0.376, blue: 0.086)
        }
        return scheme == .dark ? Color(red: 0.569, green: 0.737, blue: 0.616) : Color(red: 0.259, green: 0.471, blue: 0.353)
    }
}

struct WidgetView: View {
    @ObservedObject var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @State private var details: Account?
    @State private var removal: Account?
    @State private var rename: Account?
    @State private var renamedAlias = ""
    @State private var pendingOrganization: ClaudeOrganization?
    @State private var pendingOrganizationAccount: Account?

    var body: some View {
        VStack(spacing: 0) {
            header
            if let error = store.globalError {
                Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                    .padding(.horizontal, 20).padding(.bottom, 12)
            }
            if store.ledger.accounts.isEmpty {
                empty
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        if store.accounts.isEmpty {
                            Text(tr("No accounts for this provider."))
                                .foregroundStyle(Palette.muted(scheme)).padding(24)
                        }
                        ForEach(store.accounts) { account in
                            accountRow(account)
                        }
                    }.padding(.horizontal, 20)
                }
            }
            Divider()
            HStack {
                Button(tr("Add account…"), systemImage: "plus") { store.showAdd = true }
                    .buttonStyle(.plain).disabled(!store.canEditAccounts)
                Spacer()
                Text(tr(store.isDemo ? "Sample data · Demo" : "Refreshes every 5 min"))
                    .foregroundStyle(Palette.muted(scheme))
            }.font(.system(size: 12)).padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(Palette.paper(scheme))
        .onAppear {
            if store.isDemo, CommandLine.arguments.contains("--demo-oauth") || CommandLine.arguments.contains("--demo-details") {
                details = store.ledger.accounts.first(where: { $0.provider == .claude })
            } else if store.isDemo, CommandLine.arguments.contains("--demo-add") {
                store.showAdd = true
            }
        }
        .sheet(isPresented: $store.showAdd) { AddAccountView(store: store) }
        .sheet(item: $details) { account in
            AccountDetailView(store: store, account: account)
        }
        .alert(tr("Remove this account from the list?"), isPresented: Binding(
            get: { removal != nil }, set: { if !$0 { removal = nil } }
        )) {
            Button(tr("Cancel"), role: .cancel) { removal = nil }
            Button(tr("Remove from list"), role: .destructive) {
                if let account = removal { store.remove(account) }
                removal = nil
            }
        } message: {
            Text(tr("Stops display and automatic refresh in this app. Your provider account and login data are not deleted."))
        }
        .alert(tr("Rename account"), isPresented: Binding(
            get: { rename != nil }, set: { if !$0 { rename = nil } }
        )) {
            TextField(tr("Alias"), text: $renamedAlias)
            Button(tr("Cancel"), role: .cancel) { rename = nil }
            Button(tr("Rename")) {
                if let account = rename { store.rename(account.id, alias: renamedAlias) }
                rename = nil
            }
        }
        .alert(tr("Change the Claude organization?"), isPresented: Binding(
            get: { pendingOrganization != nil }, set: { if !$0 { pendingOrganization = nil } }
        )) {
            Button(tr("Cancel"), role: .cancel) { pendingOrganization = nil }
            Button(tr("Change organization")) {
                if let organization = pendingOrganization, let account = pendingOrganizationAccount {
                    store.selectOrganization(organization.id, for: account.id, confirmedChange: true)
                }
                pendingOrganization = nil
            }
        } message: {
            Text(tr("Verifies the same Claude account before connecting the new organization's usage. A failed read keeps the existing connection."))
        }
        .environment(\.locale, appLocale)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tr("Remaining quota")).font(.system(size: 18, weight: .semibold))
                Spacer()
                Button {
                    store.pinned.toggle()
                } label: { Image(systemName: store.pinned ? "pin.fill" : "pin") }
                    .help(tr("Always on top")).accessibilityLabel(tr("Always on top"))
                    .accessibilityValue(tr(store.pinned ? "On" : "Off"))
                Button { store.refreshAll() } label: { Image(systemName: "arrow.clockwise") }
                    .help(tr("Refresh all")).accessibilityLabel(tr("Refresh all")).disabled(store.isDemo)
                Menu {
                    Toggle(tr("Compact view"), isOn: $store.compact)
                    Picker(tr("Theme"), selection: $store.theme) {
                        Text(tr("System")).tag("system")
                        Text(tr("Paper")).tag("light")
                        Text(tr("Dark")).tag("dark")
                    }
                    Divider()
                    Button(tr("Settings…")) { store.onSettingsRequested?() }
                } label: { Image(systemName: "slider.horizontal.3") }
                    .menuStyle(.borderlessButton).fixedSize()
                    .help(tr("View options")).accessibilityLabel(tr("View options"))
            }.buttonStyle(.borderless)
            Picker(tr("Account filter"), selection: $store.filter) {
                Text(tr("All %d", store.ledger.accounts.count)).tag("all")
                Text("Codex").tag("codex")
                Text("Claude").tag("claude")
            }.pickerStyle(.segmented).labelsHidden()
        }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack").font(.system(size: 28)).foregroundStyle(Palette.muted(scheme))
            Text(tr("Connect your first account.")).font(.system(size: 15, weight: .medium))
            Text(tr("Keep Codex and Claude quota\ntogether in a small window."))
                .font(.system(size: 14)).foregroundStyle(Palette.muted(scheme)).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(tr("Connect account…")) { store.showAdd = true }.buttonStyle(.borderedProminent)
                .disabled(!store.canEditAccounts)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(24)
    }

    @ViewBuilder
    private func accountRow(_ account: Account) -> some View {
        let snapshot = store.ledger.snapshots[account.id]
        let limits = snapshot?.limits ?? []
        VStack(alignment: .leading, spacing: store.compact ? 4 : 8) {
            Divider()
            if store.compact {
                HStack(alignment: .top, spacing: 12) {
                    identity(account, snapshot)
                    Spacer(minLength: 0)
                    ForEach(Array(limits.prefix(2))) { limit in
                        LimitView(limit: limit, compact: true).frame(width: 64)
                    }
                    if limits.isEmpty {
                        Text("—").foregroundStyle(Palette.muted(scheme))
                            .accessibilityLabel(tr("Usage not fetched"))
                    }
                    accountMenu(account)
                }.padding(.top, 4)
            } else {
                HStack {
                    identity(account, snapshot)
                    Spacer()
                    accountMenu(account)
                }.padding(.top, 8)
                ForEach(limits) { limit in LimitView(limit: limit, compact: false) }
                if limits.isEmpty {
                    Text(tr("Usage has not been fetched yet."))
                        .font(.caption).foregroundStyle(Palette.muted(scheme))
                }
            }
            if store.busy.contains(account.id) {
                Text(tr("Checking usage…")).font(.caption).foregroundStyle(Palette.muted(scheme))
            } else if let message = store.messages[account.id] {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message).font(.caption).foregroundStyle(Palette.muted(scheme)).textSelection(.enabled)
                    HStack(spacing: 12) {
                        Button(tr("Open sign-in…")) { store.connect(account) }
                        Button(tr(store.claudeLoginPending.contains(account.id) ? "Enter authorization code…" : "Check connection")) {
                            if store.claudeLoginPending.contains(account.id) { details = account }
                            else { Task { await store.refresh(account.id) } }
                        }
                    }.font(.caption).buttonStyle(.borderless).disabled(store.isDemo)
                }
            }
            if let choices = store.organizations[account.id] {
                ForEach(choices) { organization in
                    Button(organization.name) {
                        if account.identity != nil {
                            pendingOrganizationAccount = account
                            pendingOrganization = organization
                        } else {
                            store.selectOrganization(organization.id, for: account.id)
                        }
                    }
                        .font(.caption)
                }
            }
            if let snapshot, !store.compact || store.messages[account.id] != nil ||
                Date().timeIntervalSince(snapshot.observedAt) > 600 {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let stale = store.messages[account.id] != nil || context.date.timeIntervalSince(snapshot.observedAt) > 600
                    if !store.compact || stale {
                        HStack(spacing: 4) {
                            if stale { Image(systemName: "clock").accessibilityHidden(true) }
                            Text(tr(stale ? "Last observed" : "Updated"))
                            Text(snapshot.observedAt, style: .relative)
                            Text(tr("ago"))
                        }.font(.system(size: 11)).foregroundStyle(Palette.muted(scheme))
                    }
                }
            }
        }.padding(.bottom, store.compact ? 8 : 12)
    }

    private func identity(_ account: Account, _ snapshot: UsageSnapshot?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(account.alias).font(.system(size: 14, weight: .semibold))
                .lineLimit(1).help(account.alias)
            HStack(spacing: 4) {
                Text([account.provider.title, snapshot?.plan].compactMap { $0 }.joined(separator: " · "))
                    .lineLimit(1)
                if store.compact, let snapshot, snapshot.limits.count > 2 {
                    Text("+\(snapshot.limits.count - 2)")
                        .help(tr("See additional limits in account details."))
                        .accessibilityLabel(tr("%d additional limits", snapshot.limits.count - 2))
                }
            }.font(.system(size: 12)).foregroundStyle(Palette.muted(scheme))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func accountMenu(_ account: Account) -> some View {
        Menu {
            Button(tr("Account details…")) { details = account }
            Button(tr("Show in menu bar")) { store.showInMenuBar(account) }
            Button(tr(store.claudeLoginPending.contains(account.id) ? "Enter authorization code…" : "Check connection")) {
                if store.claudeLoginPending.contains(account.id) { details = account }
                else { Task { await store.refresh(account.id) } }
            }.disabled(store.isDemo)
            Button(tr("Open sign-in…")) { store.connect(account) }.disabled(store.isDemo)
            Button(tr("Rename…")) { renamedAlias = account.alias; rename = account }.disabled(!store.canEditAccounts)
            Divider()
            Button(tr("Remove from list…"), role: .destructive) { removal = account }.disabled(!store.canEditAccounts)
        } label: { Image(systemName: "ellipsis") }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 28)
            .help(tr("Manage %@", account.alias)).accessibilityLabel(tr("Manage %@", account.alias))
    }
}

struct LimitView: View {
    let limit: UsageLimit
    let compact: Bool
    @Environment(\.colorScheme) private var scheme
    private let locale = appLocale

    var body: some View {
        VStack(alignment: compact ? .trailing : .leading, spacing: 4) {
            if compact {
                Text("\(limit.remainingPercent, specifier: "%.0f")%")
                    .font(.system(size: 14, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(Palette.quota(limit.remainingPercent, scheme))
                Text(limit.localizedTitle).font(.system(size: 11)).foregroundStyle(Palette.muted(scheme)).lineLimit(1)
                    .help(limit.localizedTitle)
            } else {
                HStack {
                    Text(limit.localizedTitle).font(.system(size: 12)).foregroundStyle(Palette.muted(scheme))
                    Spacer()
                    Text(tr("%.0f%% remaining", limit.remainingPercent))
                        .font(.system(size: 14, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(Palette.quota(limit.remainingPercent, scheme))
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(scheme == .dark ? 0.15 : 0.1))
                    Capsule().fill(Palette.quota(limit.remainingPercent, scheme))
                        .frame(width: proxy.size.width * limit.remainingPercent / 100)
                }
            }.frame(height: 4)
            if limit.remainingPercent <= 20 {
                Text(tr(limit.remainingPercent == 0 ? "Exhausted" : "Low"))
                    .font(.system(size: 11)).foregroundStyle(Palette.muted(scheme))
            }
            if !compact, let reset = limit.resetsAt {
                HStack(spacing: 4) {
                    Text(reset.formatted(.dateTime.month().day().hour().minute().locale(locale)))
                    Text(tr("reset"))
                }.font(.system(size: 12)).foregroundStyle(Palette.muted(scheme))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("%@ remaining quota", limit.localizedTitle))
        .accessibilityValue(accessibleValue)
        .help(tr("%@: %d%% remaining", limit.localizedTitle, Int(limit.remainingPercent.rounded())))
    }

    private var accessibleValue: String {
        var value = tr("%d percent", Int(limit.remainingPercent.rounded()))
        if limit.remainingPercent <= 20 { value += ", " + tr(limit.remainingPercent == 0 ? "Exhausted" : "Low") }
        if let reset = limit.resetsAt { value += ", " + tr("Resets %@", reset.formatted(.dateTime.locale(locale))) }
        return value
    }
}

struct AddAccountView: View {
    @ObservedObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var alias = ""
    @State private var provider: Provider = .codex
    @State private var existingHome = ""
    @State private var useExistingHome = false
    @State private var executablePath = ""
    @State private var connectionError: String?
    @State private var connecting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tr("Connect account")).font(.title2.weight(.semibold))
            Form {
                TextField(tr("Alias"), text: $alias, prompt: Text(tr("Personal account")))
                Picker(tr("Provider"), selection: $provider) {
                    ForEach(Provider.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                if provider == .codex {
                    Toggle(tr("Connect existing Codex profile"), isOn: $useExistingHome)
                    if useExistingHome { TextField("CODEX_HOME", text: $existingHome, prompt: Text("~/.codex")) }
                    TextField(tr("Codex executable"), text: $executablePath)
                }
            }
            if let connectionError {
                Text(connectionError).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
            Text(tr(provider == .claude
                 ? "Sign in to Claude in your default browser, then enter the authorization code here. Usage refreshes every five minutes without keeping a browser or CLI open."
                 : "New accounts sign in with separate Codex profiles. An existing profile reads only that profile's account."))
                .font(.system(size: 13)).foregroundStyle(Palette.muted(scheme)).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(tr("Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(tr("Connect")) {
                    connecting = true
                    connectionError = nil
                    Task {
                        defer { connecting = false }
                        do {
                            try await store.add(alias: alias, provider: provider,
                                existingHome: useExistingHome ? existingHome : nil, executablePath: executablePath)
                        } catch { connectionError = error.localizedDescription }
                    }
                }.keyboardShortcut(.defaultAction)
                    .disabled(connecting || alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (provider == .codex && useExistingHome && existingHome.isEmpty))
            }
        }.padding(24).frame(width: 400)
            .onAppear {
                executablePath = store.codexPath
                if store.isDemo, CommandLine.arguments.contains("--demo-claude") { provider = .claude }
            }
    }
}

struct AccountDetailView: View {
    @ObservedObject var store: AppStore
    let account: Account
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var authorizationCode = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(account.alias).font(.title2.weight(.semibold))
            Text(account.provider.title).foregroundStyle(Palette.muted(scheme))
            if let snapshot = store.ledger.snapshots[account.id] {
                Text(snapshot.displayIdentity).font(.caption).textSelection(.enabled)
                ForEach(snapshot.limits) { LimitView(limit: $0, compact: false) }
                Text(tr("Last updated: %@", snapshot.observedAt.formatted(.dateTime.locale(appLocale))))
                    .font(.caption).foregroundStyle(Palette.muted(scheme)).textSelection(.enabled)
            } else if !store.claudeLoginPending.contains(account.id) {
                Text(tr("Sign in, then choose Check connection.")).foregroundStyle(Palette.muted(scheme))
            }
            if let message = store.messages[account.id] {
                Text(message).font(.caption).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if store.claudeLoginPending.contains(account.id) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(tr("Connect browser sign-in")).font(.headline)
                    if store.claudeLoginRetryable.contains(account.id) {
                        Text(tr("The code was processed. Retry account verification."))
                            .font(.caption).fixedSize(horizontal: false, vertical: true)
                        Button(tr("Retry account verification")) {
                            Task { await store.completeClaudeLogin(account.id, code: "") }
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(store.busy.contains(account.id))
                    } else {
                    Text(tr("Sign in with Google or email in your default browser, then paste the entire authorization code."))
                        .font(.caption).foregroundStyle(Palette.muted(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(tr("Authorization code")).font(.caption)
                    SecureField(tr("Entire code from the browser"), text: $authorizationCode)
                        .textFieldStyle(.roundedBorder)
                    Button(tr("Paste")) {
                        if let pasted = NSPasteboard.general.string(forType: .string) {
                            authorizationCode = pasted
                        }
                    }.keyboardShortcut("v", modifiers: .control)
                    Button(tr("Connect with code")) {
                        let code = authorizationCode
                        authorizationCode = ""
                        Task { await store.completeClaudeLogin(account.id, code: code) }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(authorizationCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              store.busy.contains(account.id))
                    }
                }
            }
            if store.busy.contains(account.id) {
                Text(tr("Checking usage…")).font(.caption).foregroundStyle(Palette.muted(scheme))
            }
            HStack {
                Button(tr("Sign in…")) { store.connect(account) }
                    .disabled(store.isDemo || store.busy.contains(account.id))
                if !store.claudeLoginPending.contains(account.id) {
                    Button(tr("Check connection")) { Task { await store.refresh(account.id) } }
                        .disabled(store.isDemo || store.busy.contains(account.id))
                }
                Spacer()
                Button(tr("Close")) { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }.padding(24).frame(width: 320)
    }
}
