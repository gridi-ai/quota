import Foundation

public enum DemoData {
    public static func ledger(at now: Date = Date()) throws -> AccountLedger {
        let rows: [(String, Provider, Double, Double)] = [
            ("개인 계정", .codex, 0, 57),
            ("업무 계정", .claude, 14, 39),
            ("프로젝트 계정", .codex, 0, 88),
            ("보조 계정", .claude, 5, 21)
        ]
        var ledger = AccountLedger()
        for (alias, provider, short, weekly) in rows {
            let account = Account(alias: alias, provider: provider)
            ledger.accounts.append(account)
            var limits: [UsageLimit] = []
            if provider == .claude {
                limits.append(try UsageLimit(
                    id: "five_hour", title: "5시간", usedPercent: short,
                    windowMinutes: 300, resetsAt: now.addingTimeInterval(8000)
                ))
            }
            limits.append(try UsageLimit(
                id: "seven_day", title: "주간", usedPercent: weekly,
                windowMinutes: 10080, resetsAt: now.addingTimeInterval(180000)
            ))
            try ledger.apply(UsageSnapshot(
                identity: alias, displayIdentity: "예시 데이터",
                plan: provider == .codex ? "Plus" : "Max", limits: limits, observedAt: now
            ), to: account.id)
        }
        return ledger
    }
}
