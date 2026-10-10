import Foundation

public enum DemoData {
    public static func ledger(at now: Date = Date()) throws -> AccountLedger {
        let rows: [(String, Provider, Double, Double)] = [
            (L10n.text("Personal account"), .codex, 0, 57),
            (L10n.text("Work account"), .claude, 14, 39),
            (L10n.text("Project account"), .codex, 0, 88),
            (L10n.text("Secondary account"), .claude, 5, 21)
        ]
        var ledger = AccountLedger()
        for (alias, provider, short, weekly) in rows {
            let account = Account(alias: alias, provider: provider)
            ledger.accounts.append(account)
            var limits: [UsageLimit] = []
            if provider == .claude {
                limits.append(try UsageLimit(
                    id: "five_hour", title: "5 hours", usedPercent: short,
                    windowMinutes: 300, resetsAt: now.addingTimeInterval(8000)
                ))
            }
            limits.append(try UsageLimit(
                id: "seven_day", title: "Weekly", usedPercent: weekly,
                windowMinutes: 10080, resetsAt: now.addingTimeInterval(180000)
            ))
            try ledger.apply(UsageSnapshot(
                identity: alias, displayIdentity: L10n.text("Sample data"),
                plan: provider == .codex ? "Plus" : "Max", limits: limits, observedAt: now
            ), to: account.id)
        }
        return ledger
    }
}
