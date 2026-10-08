import Foundation
import Testing
@testable import QuotaCore

private actor OAuthFixtureTransport {
    private var replies: [(Int, Data)]
    private(set) var requests: [URLRequest] = []

    init(_ replies: [(Int, String)]) {
        self.replies = replies.map { ($0.0, Data($0.1.utf8)) }
    }

    func send(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let reply = try #require(replies.first)
        replies.removeFirst()
        let url = try #require(request.url)
        let response = try #require(HTTPURLResponse(url: url, statusCode: reply.0, httpVersion: nil, headerFields: nil))
        return (reply.1, response)
    }
}

private let oauthProfile = #"{"account":{"uuid":"account-a","email":"a@example.test"},"organization":{"uuid":"org-a"}}"#
private let oauthUsage = #"{"five_hour":{"utilization":24,"resets_at":"2026-10-09T12:00:00Z"},"seven_day":null}"#
private let oauthTokens = #"{"access_token":"access-a","refresh_token":"refresh+a","expires_in":3600,"scope":"user:profile"}"#

@Test func claudeBrowserFlowUsesPKCEAndReadOnlyScope() throws {
    let flow = ClaudeOAuthFlow(
        verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk", state: "account-state"
    )
    let url = try flow.authorizationURL()
    let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
    let fields = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    #expect(url.host == "claude.com")
    #expect(fields["code_challenge"] == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    #expect(fields["code_challenge_method"] == "S256")
    #expect(fields["scope"] == "user:profile")
    #expect(fields["state"] == "account-state")
    #expect(fields["redirect_uri"] == ClaudeOAuthFlow.redirectURI)
    #expect(fields["code_verifier"] == nil)
}

@Test func claudeBrowserFlowsAreDistinct() throws {
    let first = try ClaudeOAuthFlow()
    let second = try ClaudeOAuthFlow()
    #expect(first.state != second.state)
    #expect(first.verifier != second.verifier)
    #expect(first.verifier.count == 43)
}

@Test(arguments: ["code#other-account", "code", "#expected", "code#expected#extra"])
func claudeRejectsWrongStateBeforeNetwork(_ code: String) async throws {
    let mock = OAuthFixtureTransport([])
    let client = ClaudeOAuthClient(transport: { try await mock.send($0) })
    do {
        _ = try await client.exchange(flow: ClaudeOAuthFlow(verifier: "verifier", state: "expected"), code: code)
        Issue.record("Mismatched authorization code was accepted")
    } catch let error as UsageError {
        guard case .providerMessage = error else { throw error }
    }
    #expect(await mock.requests.isEmpty)
}

@Test func claudeCodeExchangeSendsBoundCodeAndVerifier() async throws {
    let mock = OAuthFixtureTransport([(200, oauthTokens)])
    let client = ClaudeOAuthClient(transport: { try await mock.send($0) })
    let now = Date(timeIntervalSince1970: 1000)
    let tokens = try await client.exchange(
        flow: ClaudeOAuthFlow(verifier: "verifier-a", state: "state-a"), code: "code-a#state-a", now: now
    )
    #expect(tokens.accessToken == "access-a")
    #expect(tokens.expiresAt == now.addingTimeInterval(3600))
    let request = try #require(await mock.requests.first)
    let body = try #require(request.httpBody)
    let fields = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
    #expect(fields["code"] == "code-a")
    #expect(fields["state"] == "state-a")
    #expect(fields["code_verifier"] == "verifier-a")
    #expect(fields["grant_type"] == "authorization_code")
    #expect(request.httpMethod == "POST")
}

@Test func claudeRefreshPreservesLiteralTokenAndScopes() async throws {
    let mock = OAuthFixtureTransport([(200, #"{"access_token":"access-b","expires_in":7200}"#)])
    let client = ClaudeOAuthClient(transport: { try await mock.send($0) })
    let previous = ClaudeOAuthTokens(
        accessToken: "old", refreshToken: "refresh+a", expiresAt: .distantPast, scopes: ["user:profile"]
    )
    let tokens = try await client.refresh(previous)
    #expect(tokens.refreshToken == "refresh+a")
    #expect(tokens.accessToken == "access-b")
    #expect(tokens.scopes == ["user:profile"])
    let request = try #require(await mock.requests.first)
    let body = try #require(request.httpBody)
    let fields = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
    #expect(fields["refresh_token"] == "refresh+a")
    #expect(fields["grant_type"] == "refresh_token")
}

@Test func claudeCodeExchangeWithoutScopeRetainsRequestedScope() async throws {
    let mock = OAuthFixtureTransport([
        (200, #"{"access_token":"access-a","refresh_token":"refresh-a","expires_in":3600}"#)
    ])
    let client = ClaudeOAuthClient(transport: { try await mock.send($0) })
    let tokens = try await client.exchange(
        flow: ClaudeOAuthFlow(verifier: "verifier", state: "state"), code: "code#state"
    )
    #expect(tokens.scopes == ["user:profile"])
}

@Test func claudeOAuthUsageVerifiesProfileAndDoesNotInventWindows() async throws {
    let mock = OAuthFixtureTransport([(200, oauthProfile), (200, oauthUsage)])
    let client = ClaudeOAuthClient(transport: { try await mock.send($0) })
    let tokens = ClaudeOAuthTokens(
        accessToken: "access-a", refreshToken: "refresh-a", expiresAt: .distantFuture, scopes: ["user:profile"]
    )
    let snapshot = try await client.readUsage(tokens)
    #expect(snapshot.identity == "a@example.test:org-a")
    #expect(snapshot.organizationID == "org-a")
    #expect(snapshot.limits.count == 1)
    #expect(snapshot.limits.first?.remainingPercent == 76)
    let requests = await mock.requests
    #expect(requests.map { $0.url?.path } == ["/api/oauth/profile", "/api/oauth/usage"])
    #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer access-a" })
    #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Cookie") == nil })
}

@Test func claudeOAuthSnapshotCannotReplaceAnotherAccount() throws {
    let snapshot = try ClaudeOAuthClient.snapshot(profile: Data(oauthProfile.utf8), usage: Data(oauthUsage.utf8))
    #expect(throws: UsageError.identityChanged) { try snapshot.verify(expectedIdentity: "other@example.test:org-b") }
    do {
        _ = try ClaudeOAuthClient.snapshot(
            profile: Data(#"{"account":{"email":"a@example.test"}}"#.utf8), usage: Data(oauthUsage.utf8)
        )
        Issue.record("A profile without an organization was accepted")
    } catch let error as UsageError {
        guard case .providerMessage = error else { throw error }
    }
}

@Test(arguments: [
    #"{"email_address":"a@example.test","organization_uuid":"org-a"}"#,
    #"{"emailAddress":"a@example.test","organizationUuid":"org-a"}"#,
    #"{"account":{"emailAddress":"a@example.test"},"organization":{"uuid":"org-a"}}"#
])
func claudeOAuthParsesServerProfileShapes(_ profile: String) throws {
    let snapshot = try ClaudeOAuthClient.snapshot(profile: Data(profile.utf8), usage: Data(oauthUsage.utf8))
    #expect(snapshot.identity == "a@example.test:org-a")
    #expect(snapshot.limits.first?.remainingPercent == 76)
}

@Test func claudeVerifiedProfileCanRetryUsageWithoutReexchangingCode() async throws {
    let mock = OAuthFixtureTransport([(200, oauthProfile), (429, "{}"), (200, oauthUsage)])
    let client = ClaudeOAuthClient(transport: { try await mock.send($0) })
    let tokens = ClaudeOAuthTokens(
        accessToken: "access-a", refreshToken: "refresh-a", expiresAt: .distantFuture, scopes: ["user:profile"]
    )
    let profile = try await client.readProfile(tokens)
    try ClaudeOAuthClient.profileIdentity(profile).verify(expectedIdentity: "a@example.test:org-a")
    do {
        _ = try await client.readUsage(tokens, profile: profile)
        Issue.record("Rate limited usage was accepted")
    } catch let error as UsageError {
        guard case .providerMessage = error else { throw error }
    }
    let snapshot = try await client.readUsage(tokens, profile: profile)
    #expect(snapshot.limits.first?.remainingPercent == 76)
    let requests = await mock.requests
    #expect(requests.map { $0.url?.path } == ["/api/oauth/profile", "/api/oauth/usage", "/api/oauth/usage"])
    #expect(requests.allSatisfy { $0.httpMethod == "GET" })
}

@Test func claudeUsageMetadataIsNotDecodedAsAQuotaWindow() throws {
    let usage = Data(#"""
    {"five_hour":{"utilization":24,"resets_at":"2026-10-09T12:00:00Z"},
     "seven_day":null,"limits":[{"kind":"weekly_scoped","percent":10}],
     "request_id":"metadata","extra_usage":{"is_enabled":false},"credits":42}
    """#.utf8)
    let snapshot = try ClaudeOAuthClient.snapshot(profile: Data(oauthProfile.utf8), usage: usage)
    #expect(snapshot.limits.count == 1)
    #expect(snapshot.limits.first?.remainingPercent == 76)
}

@Test(arguments: [401, 403, 429, 500])
func claudeOAuthErrorsDoNotRetryOrExposeResponseBody(_ status: Int) async throws {
    let mock = OAuthFixtureTransport([(status, #"{"error":"secret-token-must-not-escape"}"#)])
    let client = ClaudeOAuthClient(transport: { try await mock.send($0) })
    do {
        _ = try await client.exchange(
            flow: ClaudeOAuthFlow(verifier: "verifier", state: "state"), code: "code#state"
        )
        Issue.record("HTTP failure was accepted")
    } catch let error as UsageError {
        #expect(!error.localizedDescription.contains("secret-token-must-not-escape"))
        if status == 401 { #expect(error == .notAuthenticated) }
    }
    #expect(await mock.requests.count == 1)
}

@Test func claudeMissingProfileScopeFailsBeforeFetching() async throws {
    let mock = OAuthFixtureTransport([])
    let client = ClaudeOAuthClient(transport: { try await mock.send($0) })
    let tokens = ClaudeOAuthTokens(
        accessToken: "access", refreshToken: "refresh", expiresAt: .distantFuture, scopes: ["user:inference"]
    )
    do {
        _ = try await client.readUsage(tokens)
        Issue.record("A token without profile scope was accepted")
    } catch let error as UsageError {
        guard case .providerMessage = error else { throw error }
    }
    #expect(await mock.requests.isEmpty)
}
