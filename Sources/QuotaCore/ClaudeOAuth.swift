import CryptoKit
import Foundation
import Security

public struct ClaudeOAuthFlow: Sendable {
    public static let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    public static let redirectURI = "https://platform.claude.com/oauth/code/callback"
    let verifier: String
    let state: String

    public init() throws {
        func randomValue() throws -> String {
            var bytes = [UInt8](repeating: 0, count: 32)
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
                throw UsageError.providerMessage("인증 요청을 생성할 수 없습니다.")
            }
            return Self.base64URL(Data(bytes))
        }
        verifier = try randomValue()
        state = try randomValue()
    }

    init(verifier: String, state: String) {
        self.verifier = verifier
        self.state = state
    }

    public func authorizationURL() throws -> URL {
        var components = URLComponents(string: "https://claude.com/cai/oauth/authorize")
        components?.queryItems = [
            URLQueryItem(name: "code", value: "true"),
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "scope", value: "user:profile"),
            URLQueryItem(name: "code_challenge", value: Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]
        guard let url = components?.url else { throw UsageError.invalidPayload }
        return url
    }

    func authorizationCode(_ pasted: String) throws -> String {
        let parts = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "#", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, parts[1] == state else {
            throw UsageError.providerMessage("이 로그인 요청의 인증 코드 전체를 복사해 주세요. 다른 요청의 코드는 사용할 수 없습니다.")
        }
        return String(parts[0])
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

public struct ClaudeOAuthTokens: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Date
    public let scopes: [String]

    public init(accessToken: String, refreshToken: String, expiresAt: Date, scopes: [String]) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.scopes = scopes
    }
}

public struct ClaudeOAuthClient: Sendable {
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
    private let transport: Transport

    public init(transport: @escaping Transport = ClaudeOAuthClient.send) {
        self.transport = transport
    }

    public func exchange(flow: ClaudeOAuthFlow, code: String, now: Date = Date()) async throws -> ClaudeOAuthTokens {
        let code = try flow.authorizationCode(code)
        let data = try await request(
            "https://platform.claude.com/v1/oauth/token",
            body: [
                "grant_type": "authorization_code", "code": code, "state": flow.state,
                "client_id": ClaudeOAuthFlow.clientID, "redirect_uri": ClaudeOAuthFlow.redirectURI,
                "code_verifier": flow.verifier
            ]
        )
        return try tokens(from: data, previous: nil, now: now)
    }

    public func refresh(_ previous: ClaudeOAuthTokens, now: Date = Date()) async throws -> ClaudeOAuthTokens {
        let data = try await request(
            "https://platform.claude.com/v1/oauth/token",
            body: [
                "grant_type": "refresh_token", "refresh_token": previous.refreshToken,
                "client_id": ClaudeOAuthFlow.clientID
            ]
        )
        return try tokens(from: data, previous: previous, now: now)
    }

    public func readProfile(_ tokens: ClaudeOAuthTokens) async throws -> Data {
        guard tokens.scopes.contains("user:profile") else {
            throw UsageError.providerMessage("사용량 조회 권한이 없습니다. 브라우저에서 다시 연결해 주세요.")
        }
        return try await request("https://api.anthropic.com/api/oauth/profile", bearer: tokens.accessToken)
    }

    public func readUsage(_ tokens: ClaudeOAuthTokens, profile: Data? = nil, observedAt: Date = Date()) async throws -> UsageSnapshot {
        let profileData: Data
        if let profile { profileData = profile }
        else { profileData = try await readProfile(tokens) }
        let usage = try await request("https://api.anthropic.com/api/oauth/usage", bearer: tokens.accessToken)
        return try Self.snapshot(profile: profileData, usage: usage, observedAt: observedAt)
    }

    public static func profileIdentity(_ data: Data) throws -> UsageSnapshot {
        let profile: [String: Any]
        do {
            guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw UsageError.invalidPayload
            }
            profile = value
        } catch { throw UsageError.providerMessage("Claude 계정 프로필 응답이 올바른 JSON이 아닙니다.") }
        let account = profile["account"] as? [String: Any] ?? [:]
        let organization = profile["organization"] as? [String: Any] ?? [:]
        let email = (account["email_address"] ?? account["email"] ?? account["emailAddress"] ??
                     profile["email_address"] ?? profile["emailAddress"] ?? profile["email"]) as? String
        let organizationID = (organization["uuid"] ?? profile["organization_uuid"] ?? profile["organizationUuid"]) as? String
        guard let email, !email.isEmpty else {
            throw UsageError.providerMessage("Claude 계정 프로필 응답에 이메일 식별자가 없습니다.")
        }
        guard let organizationID, !organizationID.isEmpty else {
            throw UsageError.providerMessage("Claude 계정 프로필 응답에 조직 식별자가 없습니다.")
        }
        return UsageSnapshot(
            identity: email + ":" + organizationID, displayIdentity: email,
            limits: [], organizationID: organizationID
        )
    }

    public static func snapshot(profile: Data, usage: Data, observedAt: Date = Date()) throws -> UsageSnapshot {
        let identity = try profileIdentity(profile)
        guard let organizationID = identity.organizationID else { throw UsageError.invalidPayload }
        let windows: [String: Any]
        do {
            guard let value = try JSONSerialization.jsonObject(with: usage) as? [String: Any] else {
                throw UsageError.invalidPayload
            }
            windows = value
        } catch { throw UsageError.providerMessage("Claude 사용량 응답이 올바른 JSON이 아닙니다.") }
        let windowKeys: Set<String> = [
            "five_hour", "seven_day", "seven_day_sonnet", "seven_day_opus", "seven_day_cowork"
        ]
        let envelope = try JSONSerialization.data(withJSONObject: [
            "email": identity.displayIdentity, "organizationID": organizationID,
            "usage": windows.filter { windowKeys.contains($0.key) }
        ])
        do { return try ClaudePayload.parse(envelope, observedAt: observedAt) }
        catch { throw UsageError.providerMessage("Claude 사용량 한도 응답 형식을 확인할 수 없습니다.") }
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: Double
        let scope: String?
    }

    private func tokens(from data: Data, previous: ClaudeOAuthTokens?, now: Date) throws -> ClaudeOAuthTokens {
        let response: TokenResponse
        do { response = try JSONDecoder().decode(TokenResponse.self, from: data) }
        catch { throw UsageError.providerMessage("Claude 인증 토큰 응답 형식을 확인할 수 없습니다.") }
        let refresh = response.refresh_token ?? previous?.refreshToken ?? ""
        let scopes = response.scope?.split(separator: " ").map(String.init) ?? previous?.scopes ?? ["user:profile"]
        guard !response.access_token.isEmpty else {
            throw UsageError.providerMessage("Claude 인증 응답에 액세스 토큰이 없습니다.")
        }
        guard !refresh.isEmpty else {
            throw UsageError.providerMessage("Claude 인증 응답에 갱신 토큰이 없습니다.")
        }
        guard response.expires_in.isFinite, response.expires_in > 0,
              scopes.contains("user:profile") else {
            throw UsageError.providerMessage("Claude 인증 응답의 만료 시각 또는 조회 권한이 올바르지 않습니다.")
        }
        return ClaudeOAuthTokens(
            accessToken: response.access_token, refreshToken: refresh,
            expiresAt: now.addingTimeInterval(response.expires_in), scopes: scopes
        )
    }

    private func request(_ address: String, body: [String: String]? = nil, bearer: String? = nil) async throws -> Data {
        guard let url = URL(string: address) else { throw UsageError.invalidPayload }
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        if let bearer {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
            request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        }
        let (data, response) = try await transport(request)
        switch response.statusCode {
        case 200: return data
        case 401: throw UsageError.notAuthenticated
        case 429: throw UsageError.providerMessage("Claude 조회 한도에 도달했습니다. 다음 갱신을 기다려 주세요.")
        default: throw UsageError.providerMessage("Claude 인증 또는 조회 실패 (HTTP \(response.statusCode)). 브라우저에서 다시 연결해 주세요.")
        }
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        return URLSession(configuration: configuration, delegate: ClaudeOAuthRedirectGuard(), delegateQueue: nil)
    }()

    public static func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw UsageError.invalidPayload }
        return (data, response)
    }
}

private final class ClaudeOAuthRedirectGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
