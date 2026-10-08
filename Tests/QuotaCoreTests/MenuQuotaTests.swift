import Foundation
import Testing
@testable import QuotaCore

@Test func menuQuotaUsesSelectedAccountAndMostConstrainedWindow() throws {
    let now = Date(timeIntervalSince1970: 1000)
    let ledger = try DemoData.ledger(at: now)
    let selectedCodex = try #require(ledger.accounts.last { $0.provider == .codex })
    let metrics = MenuQuota.metrics(
        ledger: ledger,
        selections: ["codex": selectedCodex.id.uuidString],
        at: now
    )
    #expect(metrics.count == 2)
    #expect(metrics[0].accountID == selectedCodex.id)
    #expect(metrics[0].remainingPercent == 12)
    #expect(metrics[1].remainingPercent == 61)
    #expect(!metrics.contains { $0.isStale })
}

@Test func menuQuotaNeverInventsUnknownValues() {
    let account = Account(alias: "Unconnected", provider: .claude)
    let metrics = MenuQuota.metrics(ledger: AccountLedger(accounts: [account]))
    #expect(metrics.count == 1)
    #expect(metrics[0].remainingPercent == nil)
    #expect(MenuQuota.metrics(ledger: AccountLedger()).isEmpty)
}

@Test func menuQuotaMarksFailedOldAndResetSnapshotsAsStale() throws {
    let now = Date(timeIntervalSince1970: 1000)
    var ledger = try DemoData.ledger(at: now)
    let account = try #require(ledger.accounts.first)
    let failed = MenuQuota.metrics(ledger: ledger, failedAccounts: [account.id], at: now)
    #expect(failed[0].isStale)
    #expect(failed[0].remainingPercent == 43)
    #expect(MenuQuota.metrics(ledger: ledger, at: now.addingTimeInterval(601)).allSatisfy { $0.isStale })
    let resetLimit = try UsageLimit(
        id: "weekly", title: "주간", usedPercent: 57,
        resetsAt: now.addingTimeInterval(-1)
    )
    let snapshot = try #require(ledger.snapshots[account.id])
    try ledger.apply(UsageSnapshot(
        identity: snapshot.identity, displayIdentity: snapshot.displayIdentity,
        limits: [resetLimit], observedAt: now
    ), to: account.id)
    #expect(MenuQuota.metrics(ledger: ledger, at: now)[0].isStale)
}

@Test func menuQuotaFallsBackWhenSelectedAccountIsRemoved() throws {
    let now = Date(timeIntervalSince1970: 1000)
    var ledger = try DemoData.ledger(at: now)
    let removed = try #require(ledger.accounts.last { $0.provider == .codex })
    let selections = ["codex": removed.id.uuidString]
    ledger.remove(removed.id)
    let metric = try #require(MenuQuota.metrics(ledger: ledger, selections: selections, at: now).first)
    #expect(metric.accountID != removed.id)
    #expect(metric.remainingPercent == 43)
}
