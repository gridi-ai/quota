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
        panel.title = "남은 사용량"
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
        panel.level = store.pinned ? .floating : .normal
        applyTheme(store.theme)
        makeMenus()
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
    }

    private func resizeForContent() {
        let count = store.ledger.accounts.count
        let contentHeight: CGFloat = count == 0 ? 260 :
            store.compact ? CGFloat(min(440, 120 + count * 64)) : CGFloat(min(580, 160 + count * 130))
        let old = panel.frame
        let chrome = old.height - panel.contentLayoutRect.height
        let height = contentHeight + chrome
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
        menu.addItem(item("위젯 열기", action: #selector(showWindow), key: "0"))
        menu.addItem(item("전체 새로고침", action: #selector(refresh), key: "r"))
        menu.addItem(item("계정 추가…", action: #selector(addAccount), key: "n"))
        menu.addItem(item("보기 전환", action: #selector(toggleCompact), key: "1"))
        menu.addItem(item("항상 위에 표시 전환", action: #selector(togglePin), key: "p"))
        menu.addItem(item("설정…", action: #selector(showSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Quota 종료", action: #selector(quit), key: "q"))
        root.submenu = menu
        let editRoot = NSMenuItem(title: "편집", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "편집")
        for (title, selector, key) in [
            ("잘라내기", "cut:", "x"), ("복사", "copy:", "c"),
            ("붙여넣기", "paste:", "v"), ("전체 선택", "selectAll:", "a")
        ] {
            editMenu.addItem(NSMenuItem(title: title, action: NSSelectorFromString(selector), keyEquivalent: key))
        }
        let controlPaste = NSMenuItem(title: "붙여넣기 (Ctrl+V)", action: NSSelectorFromString("paste:"), keyEquivalent: "v")
        controlPaste.keyEquivalentModifierMask = .control
        editMenu.addItem(controlPaste)
        editRoot.submenu = editMenu
        menuBar.addItem(editRoot)
        NSApp.mainMenu = menuBar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: "Quota 사용량")
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
        statusItem.button?.toolTip = metrics.isEmpty ? "계정을 연결하면 남은 사용량이 표시됩니다." :
            metrics.compactMap { metric -> String? in
                guard let account = store.ledger.accounts.first(where: { $0.id == metric.accountID }) else { return nil }
                let limits = store.ledger.snapshots[account.id]?.limits.map {
                    "\($0.title) \(Int($0.remainingPercent.rounded()))% 남음"
                }.joined(separator: ", ") ?? "미조회"
                return "\(account.provider.title) · \(account.alias): \(limits)\(metric.isStale ? " (마지막 관측값)" : "")"
            }.joined(separator: "\n")
        statusItem.button?.setAccessibilityLabel("계정별 남은 사용량")
        statusItem.button?.setAccessibilityValue(statusItem.button?.title ?? "")
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === statusItem.menu else { return }
        menu.removeAllItems()
        for account in store.ledger.accounts {
            let limits = store.ledger.snapshots[account.id]?.limits.map {
                "\($0.title) \(Int($0.remainingPercent.rounded()))%"
            }.joined(separator: " · ") ?? "미조회"
            let summary = NSMenuItem(title: "\(account.alias) · \(account.provider.title) · \(limits)", action: nil, keyEquivalent: "")
            summary.isEnabled = false
            menu.addItem(summary)
        }
        if !store.ledger.accounts.isEmpty { menu.addItem(.separator()) }
        menu.addItem(item("위젯 열기", action: #selector(showWindow), key: "0"))
        menu.addItem(item("전체 새로고침", action: #selector(refresh), key: "r"))
        menu.addItem(item("계정 추가…", action: #selector(addAccount), key: "n"))
        let selection = NSMenuItem(title: "메뉴 막대 표시 계정", action: nil, keyEquivalent: "")
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
        menu.addItem(item("설정…", action: #selector(showSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Quota 종료", action: #selector(quit), key: "q"))
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
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 270),
                styleMask: [.titled, .closable], backing: .buffered, defer: false
            )
            window.title = "보기 및 연결 설정"
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
        Form {
            Toggle("항상 위에 표시", isOn: $store.pinned)
            Toggle("컴팩트 보기", isOn: $store.compact)
            Picker("테마", selection: $store.theme) {
                Text("시스템").tag("system")
                Text("페이퍼").tag("light")
                Text("다크").tag("dark")
            }
            TextField("Codex 실행 파일", text: $store.codexPath)
            Text("사용량은 앱 실행 중 5분마다, 잠자기에서 깨어날 때 자동으로 갱신합니다.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(width: 440)
    }
}
