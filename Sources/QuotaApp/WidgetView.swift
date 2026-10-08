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
                            Text("이 제공자의 계정이 없습니다.")
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
                Button("계정 추가…", systemImage: "plus") { store.showAdd = true }
                    .buttonStyle(.plain).disabled(!store.canEditAccounts)
                Spacer()
                Text(store.isDemo ? "예시 데이터 · 데모" : "5분마다 자동 갱신")
                    .foregroundStyle(Palette.muted(scheme))
            }.font(.system(size: 12)).padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(Palette.paper(scheme))
        .sheet(isPresented: $store.showAdd) { AddAccountView(store: store) }
        .sheet(item: $details) { account in
            AccountDetailView(store: store, account: account)
        }
        .alert("계정 목록에서 제거할까요?", isPresented: Binding(
            get: { removal != nil }, set: { if !$0 { removal = nil } }
        )) {
            Button("취소", role: .cancel) { removal = nil }
            Button("목록에서 제거", role: .destructive) {
                if let account = removal { store.remove(account) }
                removal = nil
            }
        } message: {
            Text("이 앱의 표시와 자동 조회를 중지합니다. 원래 계정과 로그인 데이터는 삭제하지 않습니다.")
        }
        .alert("계정 별칭 변경", isPresented: Binding(
            get: { rename != nil }, set: { if !$0 { rename = nil } }
        )) {
            TextField("별칭", text: $renamedAlias)
            Button("취소", role: .cancel) { rename = nil }
            Button("변경") {
                if let account = rename { store.rename(account.id, alias: renamedAlias) }
                rename = nil
            }
        }
        .alert("표시할 Claude 조직을 변경할까요?", isPresented: Binding(
            get: { pendingOrganization != nil }, set: { if !$0 { pendingOrganization = nil } }
        )) {
            Button("취소", role: .cancel) { pendingOrganization = nil }
            Button("조직 변경") {
                if let organization = pendingOrganization, let account = pendingOrganizationAccount {
                    store.selectOrganization(organization.id, for: account.id, confirmedChange: true)
                }
                pendingOrganization = nil
            }
        } message: {
            Text("같은 Claude 계정인지 다시 확인한 뒤 새 조직의 사용량으로 연결합니다. 조회에 실패하면 기존 연결을 유지합니다.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("남은 사용량").font(.system(size: 18, weight: .semibold))
                Spacer()
                Button {
                    store.pinned.toggle()
                } label: { Image(systemName: store.pinned ? "pin.fill" : "pin") }
                    .help("항상 위에 표시").accessibilityLabel("항상 위에 표시")
                    .accessibilityValue(store.pinned ? "켜짐" : "꺼짐")
                Button { store.refreshAll() } label: { Image(systemName: "arrow.clockwise") }
                    .help("전체 새로고침").accessibilityLabel("전체 새로고침").disabled(store.isDemo)
                Menu {
                    Toggle("컴팩트 보기", isOn: $store.compact)
                    Picker("테마", selection: $store.theme) {
                        Text("시스템").tag("system")
                        Text("페이퍼").tag("light")
                        Text("다크").tag("dark")
                    }
                } label: { Image(systemName: "slider.horizontal.3") }
                    .menuStyle(.borderlessButton).fixedSize()
                    .help("보기 설정").accessibilityLabel("보기 설정")
            }.buttonStyle(.borderless)
            Picker("계정 필터", selection: $store.filter) {
                Text("전체 \(store.ledger.accounts.count)").tag("all")
                Text("Codex").tag("codex")
                Text("Claude").tag("claude")
            }.pickerStyle(.segmented).labelsHidden()
        }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 8)
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.stack").font(.system(size: 28)).foregroundStyle(Palette.muted(scheme))
            Text("첫 계정을 연결해 주세요.").font(.system(size: 15, weight: .medium))
            Text("Codex와 Claude의 남은 사용량을\n작은 창에서 함께 확인하세요.")
                .font(.system(size: 14)).foregroundStyle(Palette.muted(scheme)).multilineTextAlignment(.center)
            Button("계정 연결…") { store.showAdd = true }.buttonStyle(.borderedProminent)
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
                            .accessibilityLabel("사용량 미조회")
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
                    Text("사용량을 아직 조회하지 않았습니다.")
                        .font(.caption).foregroundStyle(Palette.muted(scheme))
                }
            }
            if store.busy.contains(account.id) {
                Text("사용량 확인 중…").font(.caption).foregroundStyle(Palette.muted(scheme))
            } else if let message = store.messages[account.id] {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message).font(.caption).foregroundStyle(Palette.muted(scheme)).textSelection(.enabled)
                    HStack(spacing: 12) {
                        Button("로그인 열기…") { store.connect(account) }
                        Button(store.claudeLoginPending.contains(account.id) ? "인증 코드 입력…" : "연결 확인") {
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
                            Text(stale ? "마지막 관측" : "갱신")
                            Text(snapshot.observedAt, style: .relative)
                            Text("전")
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
                        .help("추가 한도는 상세 보기에서 확인할 수 있습니다.")
                        .accessibilityLabel("추가 한도 \(snapshot.limits.count - 2)개")
                }
            }.font(.system(size: 12)).foregroundStyle(Palette.muted(scheme))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func accountMenu(_ account: Account) -> some View {
        Menu {
            Button("상세 보기…") { details = account }
            Button("메뉴 막대에 표시") { store.showInMenuBar(account) }
            Button(store.claudeLoginPending.contains(account.id) ? "인증 코드 입력…" : "연결 확인") {
                if store.claudeLoginPending.contains(account.id) { details = account }
                else { Task { await store.refresh(account.id) } }
            }.disabled(store.isDemo)
            Button("로그인 열기…") { store.connect(account) }.disabled(store.isDemo)
            Button("별칭 변경…") { renamedAlias = account.alias; rename = account }.disabled(!store.canEditAccounts)
            Divider()
            Button("목록에서 제거…", role: .destructive) { removal = account }.disabled(!store.canEditAccounts)
        } label: { Image(systemName: "ellipsis") }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 28)
            .help("\(account.alias) 관리").accessibilityLabel("\(account.alias) 관리")
    }
}

struct LimitView: View {
    let limit: UsageLimit
    let compact: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: compact ? .trailing : .leading, spacing: 4) {
            if compact {
                Text("\(limit.remainingPercent, specifier: "%.0f")%")
                    .font(.system(size: 14, weight: .semibold)).monospacedDigit()
                    .foregroundStyle(Palette.quota(limit.remainingPercent, scheme))
                Text(limit.title).font(.system(size: 11)).foregroundStyle(Palette.muted(scheme)).lineLimit(1)
                    .help(limit.title)
            } else {
                HStack {
                    Text(limit.title).font(.system(size: 12)).foregroundStyle(Palette.muted(scheme))
                    Spacer()
                    Text("\(limit.remainingPercent, specifier: "%.0f")% 남음")
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
                Text(limit.remainingPercent == 0 ? "소진" : "부족")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted(scheme))
            }
            if !compact, let reset = limit.resetsAt {
                HStack(spacing: 4) {
                    Text(reset, format: .dateTime.month().day().hour().minute())
                    Text("리셋")
                }.font(.system(size: 12)).foregroundStyle(Palette.muted(scheme))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(limit.title) 남은 사용량")
        .accessibilityValue(accessibleValue)
        .help("\(limit.title): \(Int(limit.remainingPercent.rounded()))% 남음")
    }

    private var accessibleValue: String {
        var value = "\(Int(limit.remainingPercent.rounded()))퍼센트"
        if limit.remainingPercent <= 20 { value += limit.remainingPercent == 0 ? ", 소진" : ", 부족" }
        if let reset = limit.resetsAt { value += ", \(reset.formatted()) 리셋" }
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
            Text("계정 연결").font(.title2.weight(.semibold))
            Form {
                TextField("별칭", text: $alias, prompt: Text("개인 계정"))
                Picker("제공자", selection: $provider) {
                    ForEach(Provider.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                if provider == .codex {
                    Toggle("기존 Codex 프로필 연결", isOn: $useExistingHome)
                    if useExistingHome { TextField("CODEX_HOME", text: $existingHome, prompt: Text("~/.codex")) }
                    TextField("Codex 실행 파일", text: $executablePath)
                }
            }
            if let connectionError {
                Text(connectionError).font(.caption).foregroundStyle(.red).textSelection(.enabled)
            }
            Text(provider == .claude
                 ? "기본 브라우저에서 Claude에 로그인합니다. 로그인 뒤 표시되는 인증 코드를 앱에 입력하면 브라우저나 CLI를 켜두지 않아도 5분마다 조회합니다."
                 : "새 계정은 별도 Codex 프로필로 로그인합니다. 기존 프로필을 선택하면 그 프로필의 계정만 조회합니다.")
                .font(.system(size: 13)).foregroundStyle(Palette.muted(scheme)).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("취소") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("연결") {
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
        }.padding(24).frame(width: 320)
            .onAppear { executablePath = store.codexPath }
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
                Text("마지막 갱신: \(snapshot.observedAt.formatted())")
                    .font(.caption).foregroundStyle(Palette.muted(scheme)).textSelection(.enabled)
            } else if !store.claudeLoginPending.contains(account.id) {
                Text("로그인 후 연결 확인을 눌러 주세요.").foregroundStyle(Palette.muted(scheme))
            }
            if let message = store.messages[account.id] {
                Text(message).font(.caption).textSelection(.enabled)
            }
            if store.claudeLoginPending.contains(account.id) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("브라우저 로그인 연결").font(.headline)
                    if store.claudeLoginRetryable.contains(account.id) {
                        Text("인증 코드는 처리되었습니다. 계정 연결 확인을 다시 시도해 주세요.")
                            .font(.caption).fixedSize(horizontal: false, vertical: true)
                        Button("계정 연결 다시 확인") {
                            Task { await store.completeClaudeLogin(account.id, code: "") }
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .disabled(store.busy.contains(account.id))
                    } else {
                    Text("기본 브라우저에서 Google 또는 이메일로 로그인한 뒤 표시되는 인증 코드 전체를 붙여넣어 주세요.")
                        .font(.caption).foregroundStyle(Palette.muted(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("인증 코드").font(.caption)
                    SecureField("브라우저의 인증 코드 전체", text: $authorizationCode)
                        .textFieldStyle(.roundedBorder)
                    Button("붙여넣기") {
                        if let pasted = NSPasteboard.general.string(forType: .string) {
                            authorizationCode = pasted
                        }
                    }.keyboardShortcut("v", modifiers: .control)
                    Button("인증 코드로 연결") {
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
                Text("사용량 확인 중…").font(.caption).foregroundStyle(Palette.muted(scheme))
            }
            HStack {
                Button(account.provider == .claude ? "브라우저 로그인…" : "로그인 열기…") { store.connect(account) }
                    .disabled(store.isDemo || store.busy.contains(account.id))
                if !store.claudeLoginPending.contains(account.id) {
                    Button("연결 확인") { Task { await store.refresh(account.id) } }
                        .disabled(store.isDemo || store.busy.contains(account.id))
                }
                Spacer()
                Button("닫기") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }.padding(24).frame(width: 320)
    }
}
