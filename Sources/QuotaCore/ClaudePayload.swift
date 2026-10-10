import Foundation

public enum ClaudePayload {
    private struct Envelope: Decodable {
        let email: String
        let organizationID: String
        let plan: String?
        let usage: [String: Window?]
    }

    private struct Window: Decodable {
        let utilization: Double?
        let resets_at: String?
    }

    public static func parse(_ data: Data, observedAt: Date = Date()) throws -> UsageSnapshot {
        let envelope: Envelope
        do { envelope = try JSONDecoder().decode(Envelope.self, from: data) }
        catch { throw UsageError.invalidPayload }
        guard !envelope.email.isEmpty, !envelope.organizationID.isEmpty else {
            throw UsageError.invalidPayload
        }
        let definitions: [(String, String, Int)] = [
            ("five_hour", "5 hours", 300),
            ("seven_day", "Weekly", 10080),
            ("seven_day_sonnet", "Sonnet · Weekly", 10080),
            ("seven_day_opus", "Opus · Weekly", 10080),
            ("seven_day_cowork", "Cowork · Weekly", 10080)
        ]
        let limits = try definitions.compactMap { key, title, minutes -> UsageLimit? in
            guard let window = envelope.usage[key] ?? nil, let used = window.utilization else { return nil }
            var reset: Date?
            if let value = window.resets_at {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                reset = formatter.date(from: value)
                if reset == nil {
                    formatter.formatOptions = [.withInternetDateTime]
                    reset = formatter.date(from: value)
                }
                guard reset != nil else { throw UsageError.invalidPayload }
            }
            return try UsageLimit(id: key, title: title, usedPercent: used, windowMinutes: minutes, resetsAt: reset)
        }
        return UsageSnapshot(
            identity: envelope.email + ":" + envelope.organizationID,
            displayIdentity: envelope.email,
            plan: envelope.plan,
            limits: limits,
            observedAt: observedAt,
            organizationID: envelope.organizationID
        )
    }
}
