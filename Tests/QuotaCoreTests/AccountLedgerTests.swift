import Foundation
import Testing
@testable import QuotaCore

@Test func removedAccountCannotReceiveAnInFlightSnapshot() throws {
    let account = Account(alias: "Test", provider: .claude)
    var ledger = AccountLedger(accounts: [account])
    ledger.remove(account.id)
    let snapshot = UsageSnapshot(identity: "a:org", displayIdentity: "a", limits: [])
    #expect(try ledger.apply(snapshot, to: account.id) == false)
    #expect(ledger.snapshots.isEmpty)
}

@Test func identityFailurePreservesOtherAccountsAndLastKnownSnapshot() throws {
    let first = Account(alias: "First", provider: .claude)
    let second = Account(alias: "Second", provider: .claude)
    var ledger = AccountLedger(accounts: [first, second])
    let old = UsageSnapshot(identity: "a:org", displayIdentity: "a", limits: [])
    let other = UsageSnapshot(identity: "b:org", displayIdentity: "b", limits: [])
    try ledger.apply(old, to: first.id)
    try ledger.apply(other, to: second.id)
    #expect(throws: UsageError.identityChanged) {
        try ledger.apply(other, to: first.id)
    }
    #expect(ledger.snapshots[first.id] == old)
    #expect(ledger.snapshots[second.id] == other)
}

@Test func accountBindingAndObservationTimestampSurvivePersistence() throws {
    let account = Account(alias: "Test", provider: .codex, codexHome: "/isolated/profile")
    var ledger = AccountLedger(accounts: [account])
    let snapshot = UsageSnapshot(identity: "test@example.test", displayIdentity: "test@example.test", limits: [], observedAt: Date(timeIntervalSince1970: 456))
    try ledger.apply(snapshot, to: account.id)
    let restored = try JSONDecoder().decode(AccountLedger.self, from: JSONEncoder().encode(ledger))
    #expect(restored == ledger)
    #expect(restored.accounts[0].identity == snapshot.identity)
}

@Test func explicitOrganizationChangeRetainsAccountIdentity() throws {
    let account = Account(alias: "Claude", provider: .claude)
    var ledger = AccountLedger(accounts: [account])
    let previous = UsageSnapshot(identity: "a:old", displayIdentity: "a", limits: [], organizationID: "old")
    try ledger.apply(previous, to: account.id)
    let changed = UsageSnapshot(identity: "a:new", displayIdentity: "a", limits: [], organizationID: "new")
    #expect(throws: UsageError.identityChanged) { try ledger.apply(changed, to: account.id) }
    #expect(ledger.accounts[0].organizationID == "old")
    try ledger.changeOrganization(changed, for: account.id)
    #expect(ledger.accounts[0].organizationID == "new")
    #expect(ledger.accounts[0].identity == "a:new")
}

@Test func organizationChangeCannotSwitchToAnotherClaudeAccount() throws {
    let account = Account(alias: "Claude", provider: .claude)
    var ledger = AccountLedger(accounts: [account])
    let previous = UsageSnapshot(identity: "a:old", displayIdentity: "a", limits: [], organizationID: "old")
    try ledger.apply(previous, to: account.id)
    let wrong = UsageSnapshot(identity: "b:new", displayIdentity: "b", limits: [], organizationID: "new")
    #expect(throws: UsageError.identityChanged) { try ledger.changeOrganization(wrong, for: account.id) }
    #expect(ledger.snapshots[account.id] == previous)
    #expect(ledger.accounts[0].organizationID == "old")
}
