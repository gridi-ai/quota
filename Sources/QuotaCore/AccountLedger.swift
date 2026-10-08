import Foundation

public struct AccountLedger: Codable, Equatable, Sendable {
    public var accounts: [Account]
    public private(set) var snapshots: [UUID: UsageSnapshot]

    public init(accounts: [Account] = [], snapshots: [UUID: UsageSnapshot] = [:]) {
        self.accounts = accounts
        self.snapshots = snapshots
    }

    @discardableResult
    public mutating func apply(_ snapshot: UsageSnapshot, to id: UUID) throws -> Bool {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return false }
        try snapshot.verify(expectedIdentity: accounts[index].identity)
        accounts[index].identity = snapshot.identity
        accounts[index].organizationID = snapshot.organizationID
        snapshots[id] = snapshot
        return true
    }

    @discardableResult
    public mutating func changeOrganization(_ snapshot: UsageSnapshot, for id: UUID) throws -> Bool {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return false }
        guard accounts[index].provider == .claude,
              let previous = snapshots[id],
              previous.displayIdentity == snapshot.displayIdentity,
              let organizationID = snapshot.organizationID, !organizationID.isEmpty else {
            throw UsageError.identityChanged
        }
        accounts[index].identity = snapshot.identity
        accounts[index].organizationID = organizationID
        snapshots[id] = snapshot
        return true
    }

    public mutating func remove(_ id: UUID) {
        accounts.removeAll { $0.id == id }
        snapshots[id] = nil
    }
}
