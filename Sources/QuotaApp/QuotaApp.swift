import AppKit
import Combine
import SwiftUI
import QuotaCore

@main
@MainActor
enum QuotaApp {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var panel: NSPanel!
    private var statusItem: NSStatusItem!
    private var store: AppStore!
    private var settingsWindow: NSWindow?
    private var statusSubscription: AnyCancellable?
    private var statusTimer: Timer?
    private var sizeSubscription: AnyCancellable?
    private var languageSubscription: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store = AppStore(demo: CommandLine.arguments.contains("--demo"))
        if CommandLine.arguments.contains("--expanded") { store.compact = false }
        if CommandLine.arguments.contains("--dark") { store.theme = "dark" }
        if CommandLine.arguments.contains("--light") { store.theme = "light" }
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 520),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered, defer: false
        )
        panel.title = tr("Remaining quota")
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isOpaque = true
        panel.backgroundColor = .windowBackgroundColor
        panel.isFloatingPanel = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 320, height: 240)
        let hostingView = NSHostingView(rootView: WidgetView(store: store))
        // Window geometry is managed here; a zero-width minimum proposal wraps fixed-height text.
        hostingView.sizingOptions.remove(.minSize)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = true
        panel.contentView = hostingView
        panel.delegate = self
        panel.setFrameAutosaveName(store.isDemo ? "QuotaDemoWindow" : "QuotaWindow")
        if !panel.setFrameUsingName(store.isDemo ? "QuotaDemoWindow" : "QuotaWindow") { panel.center() }
        resizeForContent()
        store.onPinChanged = { [weak self] pinned in self?.panel.level = pinned ? .floating : .normal }
        store.onThemeChanged = { [weak self] theme in self?.applyTheme(theme) }
        store.onSettingsRequested = { [weak self] in self?.showSettings() }
        panel.level = store.pinned ? .floating : .normal
        applyTheme(store.theme)
        makeMenus()
        languageSubscription = store.$language.dropFirst().receive(on: RunLoop.main).sink { [weak self] _ in
            guard let self else { return }
            self.panel.title = tr("Remaining quota")
            self.settingsWindow?.title = tr("Settings")
            self.makeMenus()
        }
        statusSubscription = Publishers.CombineLatest3(store.$ledger, store.$messages, store.$menuSelections)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatus() }
        statusTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateStatus() }
        }
        sizeSubscription = Publishers.CombineLatest(
            store.$compact, store.$ledger.map { $0.accounts.count }.removeDuplicates()
        ).receive(on: RunLoop.main).sink { [weak self] _ in self?.resizeForContent() }
        showWindow()
        if store.isDemo, CommandLine.arguments.contains("--demo-settings") { showSettings() }
    }

    private func resizeForContent() {
        let count = store.ledger.accounts.count
        let contentHeight: CGFloat = count == 0 ? 320 :
            store.compact ? CGFloat(min(440, 120 + count * 64)) : CGFloat(min(580, 160 + count * 130))
        let old = panel.frame
        let height = panel.frameRect(forContentRect: NSRect(
            x: 0, y: 0, width: old.width, height: contentHeight
        )).height
        panel.minSize = NSSize(width: 320, height: count == 0 ? height : 240)
        panel.setFrame(
            NSRect(x: old.minX, y: old.maxY - height, width: old.width, height: height),
            display: true
        )
    }
    private func makeMenus() {
        let menuBar = NSMenu()
        let root = NSMenuItem()
        menuBar.addItem(root)
        let menu = NSMenu()
        menu.addItem(item(tr("Open widget"), action: #selector(showWindow), key: "0"))
        menu.addItem(item(tr("Refresh all"), action: #selector(refresh), key: "r"))
        menu.addItem(item(tr("Add account…"), action: #selector(addAccount), key: "n"))
        menu.addItem(item(tr("Toggle compact view"), action: #selector(toggleCompact), key: "1"))
        menu.addItem(item(tr("Toggle always on top"), action: #selector(togglePin), key: "p"))
        menu.addItem(item(tr("Settings…"), action: #selector(showSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item(tr("Quit Quota"), action: #selector(quit), key: "q"))
        root.submenu = menu
        let editRoot = NSMenuItem(title: tr("Edit"), action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: tr("Edit"))
        for (title, selector, key) in [
            ("Cut", "cut:", "x"), ("Copy", "copy:", "c"),
            ("Paste", "paste:", "v"), ("Select all", "selectAll:", "a")
        ] {
            editMenu.addItem(NSMenuItem(title: tr(title), action: NSSelectorFromString(selector), keyEquivalent: key))
        }
        let controlPaste = NSMenuItem(title: tr("Paste (Ctrl+V)"), action: NSSelectorFromString("paste:"), keyEquivalent: "v")
        controlPaste.keyEquivalentModifierMask = .control
        editMenu.addItem(controlPaste)
        editRoot.submenu = editMenu
        menuBar.addItem(editRoot)
        NSApp.mainMenu = menuBar
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }
        statusItem.button?.image = NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: tr("Quota usage"))
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        let statusMenu = NSMenu()
        statusMenu.delegate = self
        statusItem.menu = statusMenu
        updateStatus()
        menuWillOpen(statusMenu)
    }

    private func updateStatus() {
        let metrics = store.menuMetrics()
        statusItem.button?.title = metrics.isEmpty ? " —" : " " + metrics.map { metric in
            let provider = metric.provider == .codex ? "C" : "Cl"
            let value = metric.remainingPercent.map { "\(Int($0.rounded()))%" } ?? "—"
            return "\(provider) \(value)\(metric.isStale ? "*" : "")"
        }.joined(separator: " · ")
        statusItem.button?.toolTip = metrics.isEmpty ? tr("Connect an account to see remaining quota.") :
            metrics.compactMap { metric -> String? in
                guard let account = store.ledger.accounts.first(where: { $0.id == metric.accountID }) else { return nil }
                let limits = store.ledger.snapshots[account.id]?.limits.map {
                    tr("%@: %d%% remaining", $0.localizedTitle, Int($0.remainingPercent.rounded()))
                }.joined(separator: ", ") ?? tr("Not fetched")
                return "\(account.provider.title) · \(account.alias): \(limits)\(metric.isStale ? " (" + tr("Last observed") + ")" : "")"
            }.joined(separator: "\n")
        statusItem.button?.setAccessibilityLabel(tr("Remaining quota per account"))
        statusItem.button?.setAccessibilityValue(statusItem.button?.title ?? "")
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === statusItem.menu else { return }
        menu.removeAllItems()
        for account in store.ledger.accounts {
            let limits = store.ledger.snapshots[account.id]?.limits.map {
                "\($0.localizedTitle) \(Int($0.remainingPercent.rounded()))%"
            }.joined(separator: " · ") ?? tr("Not fetched")
            let summary = NSMenuItem(title: "\(account.alias) · \(account.provider.title) · \(limits)", action: nil, keyEquivalent: "")
            summary.isEnabled = false
            menu.addItem(summary)
        }
        if !store.ledger.accounts.isEmpty { menu.addItem(.separator()) }
        menu.addItem(item(tr("Open widget"), action: #selector(showWindow), key: "0"))
        menu.addItem(item(tr("Refresh all"), action: #selector(refresh), key: "r"))
        menu.addItem(item(tr("Add account…"), action: #selector(addAccount), key: "n"))
        let selection = NSMenuItem(title: tr("Menu bar accounts"), action: nil, keyEquivalent: "")
        let selectionMenu = NSMenu()
        let metrics = store.menuMetrics()
        for account in store.ledger.accounts {
            let choice = item("\(account.provider.title) · \(account.alias)", action: #selector(selectMenuAccount(_:)), key: "")
            choice.representedObject = account.id.uuidString
            choice.state = metrics.contains(where: { $0.accountID == account.id }) ? .on : .off
            selectionMenu.addItem(choice)
        }
        selection.submenu = selectionMenu
        selection.isEnabled = !store.ledger.accounts.isEmpty
        menu.addItem(selection)
        menu.addItem(item(tr("Settings…"), action: #selector(showSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item(tr("Quit Quota"), action: #selector(quit), key: "q"))
    }

    @objc private func selectMenuAccount(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let account = store.ledger.accounts.first(where: { $0.id.uuidString == id }) else { return }
        store.showInMenuBar(account)
    }

    private func item(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func applyTheme(_ theme: String) {
        let appearance: NSAppearance?
        switch theme {
        case "dark": appearance = NSAppearance(named: .darkAqua)
        case "light": appearance = NSAppearance(named: .aqua)
        default: appearance = nil
        }
        panel.appearance = appearance
        settingsWindow?.appearance = appearance
    }

    @objc private func showWindow() {
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func refresh() { store.refreshAll() }
    @objc private func addAccount() { showWindow(); store.showAdd = true }
    @objc private func toggleCompact() { store.compact.toggle() }
    @objc private func togglePin() { store.pinned.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 620),
                styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
            )
            window.title = tr("Settings")
            window.minSize = NSSize(width: 480, height: 380)
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(store: store))
            window.center()
            settingsWindow = window
            applyTheme(store.theme)
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        statusTimer?.invalidate()
        statusSubscription?.cancel()
        sizeSubscription?.cancel()
        languageSubscription?.cancel()
        Task {
            await store.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

struct SettingsView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
                Form {
                    Section {
                        Picker(tr("Language"), selection: $store.language) {
                            Text(tr("System")).tag("system")
                            Text("English").tag("en")
                            Text("한국어").tag("ko")
                        }
                        Toggle(tr("Always on top"), isOn: $store.pinned)
                        Toggle(tr("Compact view"), isOn: $store.compact)
                        Picker(tr("Theme"), selection: $store.theme) {
                            Text(tr("System")).tag("system")
                            Text(tr("Paper")).tag("light")
                            Text(tr("Dark")).tag("dark")
                        }
                        TextField(tr("Codex executable"), text: $store.codexPath)
                        Text(tr("Usage refreshes every five minutes while the app runs, and after wake."))
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                    }
                    Section {
                        Text(tr("Quota is free. No subscription or paid feature unlocks."))
                            .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                        Link(destination: URL(string: "https://github.com/gridi-ai/quota/releases")!) {
                            Label(tr("Install Quota for free"), systemImage: "arrow.down.circle")
                        }
                        Link(destination: URL(string: "https://ko-fi.com/gridi")!) {
                            Label(tr("Buy the developer a coffee"), systemImage: "cup.and.saucer")
                        }
                        Text(tr("Optional support. All features stay free, whether or not you donate."))
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                        Link(destination: URL(string: "https://github.com/gridi-ai/quota/issues")!) {
                            Label(tr("Report a bug"), systemImage: "arrow.up.right.square")
                        }
                    } header: {
                        Text(tr("Free installation & support"))
                    }
                }.formStyle(.grouped)
            HStack {
                Text("Quota \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(tr("Close")) { NSApp.keyWindow?.close() }.keyboardShortcut(.cancelAction)
            }
        }.padding(24).frame(minWidth: 432, maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.locale, appLocale)
    }
}
