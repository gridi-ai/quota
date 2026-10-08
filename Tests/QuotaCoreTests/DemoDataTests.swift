import Foundation
import Testing
@testable import QuotaCore

@Test func demoUsesProviderSpecificWindows() throws {
    let ledger = try DemoData.ledger(at: Date(timeIntervalSince1970: 123))
    for account in ledger.accounts {
        let snapshot = try #require(ledger.snapshots[account.id])
        if account.provider == .codex {
            #expect(snapshot.limits.map(\.windowMinutes) == [10080])
            #expect(!snapshot.limits.contains { $0.id == "five_hour" })
        } else {
            #expect(snapshot.limits.map(\.windowMinutes) == [300, 10080])
        }
        #expect(snapshot.observedAt == Date(timeIntervalSince1970: 123))
    }
}
