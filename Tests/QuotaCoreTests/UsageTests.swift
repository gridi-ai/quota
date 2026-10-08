import Foundation
import Testing
@testable import QuotaCore

@Test func remainingIsNotUsedPercentage() throws {
    let limit = try UsageLimit(id: "five_hour", title: "5시간", usedPercent: 28)
    #expect(limit.remainingPercent == 72)
    #expect(try UsageLimit(id: "full", title: "주간", usedPercent: 100).remainingPercent == 0)
}

@Test func malformedPercentagesAreRejected() {
    for invalid in [-1.0, 101, .infinity, .nan] {
        #expect(throws: UsageError.invalidPayload) {
            _ = try UsageLimit(id: "invalid", title: "한도", usedPercent: invalid)
        }
    }
}

@Test func claudeParsesIndependentWindowsAndServerReset() throws {
    let data = Data(#"{"email":"a@example.test","organizationID":"org-a","plan":"Max","usage":{"five_hour":{"utilization":28,"resets_at":"2026-10-07T09:00:00.000Z"},"seven_day":{"utilization":57,"resets_at":"2026-10-09T00:00:00Z"},"seven_day_opus":{"utilization":20,"resets_at":null}}}"#.utf8)
    let now = Date(timeIntervalSince1970: 123)
    let snapshot = try ClaudePayload.parse(data, observedAt: now)
    #expect(snapshot.identity == "a@example.test:org-a")
    #expect(snapshot.limits.map(\.remainingPercent) == [72, 43, 80])
    #expect(snapshot.observedAt == now)
    #expect(snapshot.limits[0].resetsAt != nil)
    #expect(snapshot.limits[2].resetsAt == nil)
}

@Test func missingWindowIsNotFullRemaining() throws {
    let data = Data(#"{"email":"a@example.test","organizationID":"org-a","usage":{"five_hour":null,"seven_day":{"utilization":40,"resets_at":null}}}"#.utf8)
    let snapshot = try ClaudePayload.parse(data)
    #expect(snapshot.limits.count == 1)
    #expect(snapshot.limits[0].id == "seven_day")
    #expect(snapshot.limits[0].remainingPercent == 60)
}

@Test func snapshotsCannotCrossAccountsOrOrganizations() throws {
    let snapshot = UsageSnapshot(identity: "a@example.test:org-a", displayIdentity: "a@example.test", limits: [])
    try snapshot.verify(expectedIdentity: snapshot.identity)
    #expect(throws: UsageError.identityChanged) {
        try snapshot.verify(expectedIdentity: "a@example.test:org-b")
    }
    #expect(throws: UsageError.identityChanged) {
        try snapshot.verify(expectedIdentity: "b@example.test:org-a")
    }
}

@Test func invalidResetAndWrongIdentityPayloadAreRejected() {
    for json in [
        #"{"email":"","organizationID":"org-a","usage":{}}"#,
        #"{"email":"a@example.test","organizationID":"org-a","usage":{"five_hour":{"utilization":5,"resets_at":"not-a-date"}}}"#
    ] {
        #expect(throws: UsageError.invalidPayload) { _ = try ClaudePayload.parse(Data(json.utf8)) }
    }
}
