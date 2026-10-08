import Foundation

public struct MenuQuota: Equatable, Sendable {
    public let provider: Provider
    public let accountID: UUID
    public let remainingPercent: Double?
    public let isStale: Bool

    public static func metrics(
        ledger: AccountLedger,
        selections: [String: String] = [:],
        failedAccounts: Set<UUID> = [],
        at now: Date = Date()
    ) -> [MenuQuota] {
        Provider.allCases.compactMap { provider in
            let accounts = ledger.accounts.filter { $0.provider == provider }
            guard let account = accounts.first(where: { $0.id.uuidString == selections[provider.rawValue] })
                ?? accounts.first else { return nil }
            let snapshot = ledger.snapshots[account.id]
            let remaining = snapshot?.limits.map(\.remainingPercent).min()
            let stale = snapshot.map {
                failedAccounts.contains(account.id) || now.timeIntervalSince($0.observedAt) > 600 ||
                $0.limits.contains { $0.resetsAt.map { $0 <= now } ?? false }
            } ?? false
            return MenuQuota(
                provider: provider, accountID: account.id,
                remainingPercent: remaining, isStale: stale
            )
        }
    }
}
