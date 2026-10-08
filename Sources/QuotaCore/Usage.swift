import Foundation

public enum Provider: String, Codable, CaseIterable, Sendable {
    case codex
    case claude

    public var title: String { self == .codex ? "Codex" : "Claude" }
}

public struct Account: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var alias: String
    public var provider: Provider
    public var codexHome: String?
    public var identity: String?
    public var organizationID: String?

    public init(id: UUID = UUID(), alias: String, provider: Provider, codexHome: String? = nil) {
        self.id = id
        self.alias = alias
        self.provider = provider
        self.codexHome = codexHome
    }
}

public struct UsageLimit: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let usedPercent: Double
    public let windowMinutes: Int?
    public let resetsAt: Date?

    public init(id: String, title: String, usedPercent: Double, windowMinutes: Int? = nil, resetsAt: Date? = nil) throws {
        guard usedPercent.isFinite, (0...100).contains(usedPercent) else {
            throw UsageError.invalidPayload
        }
        self.id = id
        self.title = title
        self.usedPercent = usedPercent
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
    }

    public var remainingPercent: Double { 100 - usedPercent }
}

public struct UsageSnapshot: Codable, Equatable, Sendable {
    public let identity: String
    public let displayIdentity: String
    public let plan: String?
    public let limits: [UsageLimit]
    public let observedAt: Date
    public let organizationID: String?

    public init(identity: String, displayIdentity: String, plan: String? = nil, limits: [UsageLimit], observedAt: Date = Date(), organizationID: String? = nil) {
        self.identity = identity
        self.displayIdentity = displayIdentity
        self.plan = plan
        self.limits = limits
        self.observedAt = observedAt
        self.organizationID = organizationID
    }

    public func verify(expectedIdentity: String?) throws {
        guard !identity.isEmpty else { throw UsageError.invalidPayload }
        if let expectedIdentity, identity != expectedIdentity {
            throw UsageError.identityChanged
        }
    }
}

public enum UsageError: Error, LocalizedError, Equatable, Sendable {
    case notAuthenticated
    case identityChanged
    case invalidPayload
    case timedOut
    case missingCLI
    case providerMessage(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated: "로그인이 필요합니다."
        case .identityChanged: "연결된 계정이 달라졌습니다. 계정을 다시 연결해 주세요."
        case .invalidPayload: "사용량 응답 형식을 확인할 수 없습니다."
        case .timedOut: "조회 시간이 초과되었습니다."
        case .missingCLI: "Codex CLI를 찾을 수 없습니다. 실행 파일 경로를 확인해 주세요."
        case .providerMessage(let message): message
        }
    }
}
