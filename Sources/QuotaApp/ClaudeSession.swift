import AppKit
import Foundation
import LocalAuthentication
import QuotaCore
import Security

struct ClaudeOrganization: Identifiable, Decodable {
    let id: String
    let name: String
}

enum ClaudeRead {
    case snapshot(UsageSnapshot)
    case organizations([ClaudeOrganization])
}

@MainActor
final class ClaudeSession {
    private let accountID: UUID
    private let client = ClaudeOAuthClient()
    private var flow: ClaudeOAuthFlow?
    private var pendingTokens: ClaudeOAuthTokens?
    private(set) var didCommitLogin = false
    private(set) var verifiedProfile: UsageSnapshot?

    var hasPendingTokens: Bool { pendingTokens != nil }

    init(accountID: UUID) {
        self.accountID = accountID
    }

    func showLogin() throws {
        let next = try ClaudeOAuthFlow()
        guard NSWorkspace.shared.open(try next.authorizationURL()) else {
            throw UsageError.providerMessage("기본 브라우저를 열 수 없습니다.")
        }
        flow = next
        pendingTokens = nil
        didCommitLogin = false
        verifiedProfile = nil
    }

    func completeLogin(code: String, expectedIdentity: String?) async throws -> UsageSnapshot {
        guard let flow else {
            throw UsageError.providerMessage("브라우저 로그인부터 다시 시작해 주세요.")
        }
        let tokens: ClaudeOAuthTokens
        if let pendingTokens { tokens = pendingTokens }
        else {
            tokens = try await client.exchange(flow: flow, code: code)
            pendingTokens = tokens
        }
        let profile = try await client.readProfile(tokens)
        let identity = try ClaudeOAuthClient.profileIdentity(profile)
        try identity.verify(expectedIdentity: expectedIdentity)
        try save(tokens, userInitiated: true)
        didCommitLogin = true
        verifiedProfile = identity
        pendingTokens = nil
        self.flow = nil
        return try await client.readUsage(tokens, profile: profile)
    }

    func readUsage(organizationID: String?) async throws -> ClaudeRead {
        var tokens = try load()
        if tokens.expiresAt.timeIntervalSinceNow < 60 {
            tokens = try await client.refresh(tokens)
            try save(tokens)
        }
        let snapshot = try await client.readUsage(tokens)
        if let organizationID, snapshot.organizationID != organizationID {
            throw UsageError.identityChanged
        }
        return .snapshot(snapshot)
    }

    func shutdown() {
        flow = nil
        pendingTokens = nil
    }

    private var keychainQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Quota.ClaudeOAuth",
            kSecAttrAccount as String: accountID.uuidString
        ]
    }

    private func load() throws -> ClaudeOAuthTokens {
        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        if status == errSecItemNotFound { throw UsageError.notAuthenticated }
        guard status == errSecSuccess, let data = value as? Data else {
            throw UsageError.providerMessage("Claude 인증 정보를 Keychain에서 읽을 수 없습니다 (\(status)).")
        }
        do { return try JSONDecoder().decode(ClaudeOAuthTokens.self, from: data) }
        catch { throw UsageError.invalidPayload }
    }

    private func save(_ tokens: ClaudeOAuthTokens, userInitiated: Bool = false) throws {
        let data = try JSONEncoder().encode(tokens)
        var query = keychainQuery
        let context = LAContext()
        context.interactionNotAllowed = !userInitiated
        query[kSecUseAuthenticationContext as String] = context
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = keychainQuery
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw UsageError.providerMessage("Claude 인증 정보를 Keychain에 저장할 수 없습니다 (\(status)).")
        }
    }
}
