import Foundation

public enum Provider: String, Codable, CaseIterable, Sendable {
    case codex
    case claude

    public var title: String { L10n.text(self == .codex ? "Codex" : "Claude") }
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

    public var localizedTitle: String {
        switch id {
        case "five_hour": return L10n.text("5 hours")
        case "seven_day": return L10n.text("Weekly")
        case "seven_day_sonnet": return L10n.text("Sonnet · Weekly")
        case "seven_day_opus": return L10n.text("Opus · Weekly")
        case "seven_day_cowork": return L10n.text("Cowork · Weekly")
        default:
            let kind = id.split(separator: "/").last.map(String.init)
            guard kind == "primary" || kind == "secondary" else { return L10n.text(title) }
            let duration = Self.durationTitle(minutes: windowMinutes, primary: kind == "primary", localized: true)
            // Preserve provider-supplied bucket names, replacing only the stored duration.
            if let separator = title.range(of: " · ", options: .backwards) {
                return "\(title[..<separator.lowerBound]) · \(duration)"
            }
            return duration
        }
    }

    static func durationTitle(minutes: Int?, primary: Bool, localized: Bool = false) -> String {
        let source: String
        let values: [CVarArg]
        if let minutes {
            if minutes == 10080 {
                source = "Weekly"
                values = []
            } else if minutes.isMultiple(of: 1440) {
                source = minutes == 1440 ? "%ld day" : "%ld days"
                values = [minutes / 1440]
            } else if minutes.isMultiple(of: 60) {
                source = minutes == 60 ? "%ld hour" : "%ld hours"
                values = [minutes / 60]
            } else if minutes > 60 {
                source = "\(minutes / 60 == 1 ? "%ld hour" : "%ld hours") \(minutes % 60 == 1 ? "%ld minute" : "%ld minutes")"
                values = [minutes / 60, minutes % 60]
            } else {
                source = minutes == 1 ? "%ld minute" : "%ld minutes"
                values = [minutes]
            }
        } else {
            source = primary ? "Short-term limit" : "Long-term limit"
            values = []
        }
        return String(format: localized ? L10n.text(source) : source, arguments: values)
    }
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
        case .notAuthenticated: L10n.text("Login is required.")
        case .identityChanged: L10n.text("The connected account has changed. Please reconnect the account.")
        case .invalidPayload: L10n.text("The usage response format could not be verified.")
        case .timedOut: L10n.text("The request timed out.")
        case .missingCLI: L10n.text("Codex CLI could not be found. Please check the executable path.")
        case .providerMessage(let message): L10n.text(message)
        }
    }
}
