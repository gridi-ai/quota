import Foundation
import Testing
import Darwin
#if !CODEX_STANDALONE_TESTS
@testable import QuotaCore
#endif

/// Each fixture validates the entire request sequence before returning data.
/// No real Codex binary, credentials, browser, or network is used.
@Suite(.serialized)
struct CodexClientTests {
    @Test func readsLegacyWindowsAndScopedEnvironment() async throws {
        let fixture = try Fixture(mode: "legacy")
        defer { fixture.remove() }
        let client = fixture.client()
        let snapshot = try await client.readUsage()
        #expect(snapshot.identity == "fixture@example.com")
        #expect(snapshot.plan == "plus")
        #expect(snapshot.limits.map(\.id) == ["codex/primary", "codex/secondary"])
        #expect(snapshot.limits.map(\.usedPercent) == [25, 73])
        #expect(snapshot.limits.map(\.windowMinutes) == [300, 10080])
        #expect(snapshot.limits.map(\.title) == ["5 hours", "Weekly"])
        #expect(snapshot.limits.first?.resetsAt == Date(timeIntervalSince1970: 1_800_000_000))
        await client.shutdown()
    }

    @Test func usesMultiBucketValuesWithoutDuplicatingLegacy() async throws {
        let fixture = try Fixture(mode: "multi")
        defer { fixture.remove() }
        let client = fixture.client()
        let snapshot = try await client.readUsage()
        #expect(snapshot.limits.map(\.id) == ["codex/primary", "codex/secondary", "review/primary"])
        #expect(snapshot.limits.map(\.usedPercent) == [40, 80, 12])
        #expect(snapshot.limits.map(\.title) == ["Codex · 5 hours", "Codex · Weekly", "Review · Short-term limit"])
        await client.shutdown()
    }

    @Test func labelsOtherWindowDurations() async throws {
        let fixture = try Fixture(mode: "durations")
        defer { fixture.remove() }
        let client = fixture.client()
        let snapshot = try await client.readUsage()
        #expect(snapshot.limits.map(\.title) == ["1 hour 30 minutes", "1 day"])
        await client.shutdown()
    }

    @Test func loginReturnsDocumentedURLAndRetainsProcessForVerification() async throws {
        let fixture = try Fixture(mode: "login")
        defer { fixture.remove() }
        let client = fixture.client()
        let url = try await client.startLogin()
        #expect(url == URL(string: "https://auth.openai.com/oauth/authorize?state=fixture"))
        // The fixture only authenticates in this same initialized connection.
        let snapshot = try await client.readUsage()
        #expect(snapshot.identity == "fixture@example.com")
        await client.shutdown()
    }

    @Test(arguments: [
        "http://auth.openai.com/oauth/authorize",
        "https://auth.openai.com.attacker.test/oauth/authorize",
        "https://attacker.test/oauth/authorize",
        "https://user@auth.openai.com/oauth/authorize",
        "https://auth.openai.com:8443/oauth/authorize"
    ])
    func rejectsUnsafeLoginURLs(_ value: String) async throws {
        let fixture = try Fixture(mode: "login", authURL: value)
        defer { fixture.remove() }
        let client = fixture.client()
        await #expect(throws: UsageError.invalidPayload) { try await client.startLogin() }
        await client.shutdown()
    }

    @Test func signedOutDoesNotRequestLimitsOrLogin() async throws {
        let fixture = try Fixture(mode: "signedOut")
        defer { fixture.remove() }
        let client = fixture.client()
        await #expect(throws: UsageError.notAuthenticated) { try await client.readUsage() }
        await client.shutdown()
    }

    @Test func propagatesRPCError() async throws {
        let fixture = try Fixture(mode: "rpcError")
        defer { fixture.remove() }
        let client = fixture.client()
        await #expect(throws: UsageError.providerMessage("fixture_error")) { try await client.readUsage() }
        await client.shutdown()
    }

    @Test(arguments: ["malformed", "oversized", "outboundLimit", "invalidPercent", "invalidWindow"])
    func rejectsInvalidProtocolData(_ mode: String) async throws {
        let fixture = try Fixture(mode: mode)
        defer { fixture.remove() }
        let client = fixture.client()
        await #expect(throws: UsageError.invalidPayload) { try await client.readUsage() }
        await client.shutdown()
    }

    @Test func EOFSettlesPendingRequest() async throws {
        let fixture = try Fixture(mode: "eof")
        defer { fixture.remove() }
        let client = fixture.client()
        await #expect(throws: (any Error).self) { try await client.readUsage() }
        await client.shutdown()
    }

    @Test func unresponsivePeerHitsRequestDeadline() async throws {
        let fixture = try Fixture(mode: "timeout")
        defer { fixture.remove() }
        let client = fixture.client(deadline: .milliseconds(150))
        await #expect(throws: UsageError.timedOut) { try await client.readUsage() }
        await client.shutdown()
    }

    @Test func shutdownAndCancellationSettleAnInFlightRequest() async throws {
        for cancel in [false, true] {
            let fixture = try Fixture(mode: "blocked")
            defer { fixture.remove() }
            // The fixture signals receipt through a FIFO. Subscribe before the RPC.
            let signal = try FileHandle(forUpdating: fixture.signal)
            let receipt = AsyncStream<Data>.makeStream(bufferingPolicy: .bufferingOldest(1))
            signal.readabilityHandler = { handle in receipt.continuation.yield(handle.availableData) }
            let client = fixture.client()
            let read = Task {
                do { return try await client.readUsage() }
                catch {
                    receipt.continuation.finish()
                    throw error
                }
            }
            var iterator = receipt.stream.makeAsyncIterator()
            let event = await iterator.next()
            #expect(event == Data([1]))
            if cancel { read.cancel() } else { await client.shutdown() }
            await #expect(throws: CancellationError.self) { try await read.value }
            await client.shutdown()
            signal.readabilityHandler = nil
            try signal.close()
            receipt.continuation.finish()
        }
    }

    @Test func missingExecutableFailsWithoutStartingAnything() async throws {
        let client = CodexClient(executablePath: "/nonexistent/quota-codex-fixture", home: URL(fileURLWithPath: "/tmp"))
        await #expect(throws: UsageError.missingCLI) { try await client.readUsage() }
        await client.shutdown()
    }
}

private struct Fixture {
    let directory: URL
    let executable: URL
    let signal: URL

    init(mode: String, authURL: String = "https://auth.openai.com/oauth/authorize?state=fixture") throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("quota-codex-\(UUID().uuidString)")
        executable = directory.appendingPathComponent("fake-codex")
        signal = directory.appendingPathComponent("receipt")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let settings = try JSONSerialization.data(withJSONObject: ["mode": mode, "authURL": authURL, "home": directory.path])
        let encoded = settings.base64EncodedString()
        let script = """
        #!/usr/bin/python3
        import base64, json, os, sys
        settings = json.loads(base64.b64decode("\(encoded)"))
        mode = settings["mode"]
        assert sys.argv[1:] == ["app-server"]
        assert os.getcwd() == "/"
        assert os.environ["CODEX_HOME"] == settings["home"]
        assert "OPENAI_API_KEY" not in os.environ
        assert "CODEX_API_KEY" not in os.environ
        def receive(method):
            value = json.loads(sys.stdin.readline())
            assert value["method"] == method
            return value
        def send(value):
            sys.stdout.write(json.dumps(value) + "\\n")
            sys.stdout.flush()
        def reply(request, value):
            send({"id": request["id"], "result": value})
        init = receive("initialize")
        assert init["params"]["clientInfo"]["name"] == "quota_usage"
        reply(init, {"userAgent": "fixture/0.155.1"})
        receive("initialized")
        if mode == "login":
            login = receive("account/login/start")
            assert login["params"] == {"type": "chatgpt"}
            reply(login, {"type": "chatgpt", "loginId": "fixture-login", "authUrl": settings["authURL"]})
            send({"method": "account/login/completed", "params": {"loginId": "unrelated", "success": False}})
            send({"method": "account/login/completed", "params": {"loginId": "fixture-login", "success": True}})
        account = receive("account/read")
        assert account["params"] == {"refreshToken": True}
        if mode == "blocked":
            with open(settings["home"] + "/receipt", "wb", buffering=0) as receipt:
                receipt.write(bytes([1]))
            sys.stdin.read()
            sys.exit(0)
        if mode == "timeout":
            sys.stdin.read()
            sys.exit(0)
        if mode == "eof":
            sys.exit(0)
        if mode == "malformed":
            sys.stdout.write("{bad-json\\n")
            sys.stdout.flush()
            sys.stdin.read()
            sys.exit(0)
        if mode == "oversized":
            sys.stdout.write("x" * 1048576)
            sys.stdout.flush()
            sys.stdin.read()
            sys.exit(0)
        if mode == "rpcError":
            send({"id": account["id"], "error": {"code": -32000, "message": "fixture_error"}})
            sys.stdin.read()
            sys.exit(0)
        if mode == "signedOut":
            reply(account, {"account": None, "requiresOpenaiAuth": True})
            assert not sys.stdin.readline()
            sys.exit(0)
        # Interleaved notifications cannot impersonate account/usage responses.
        send({"method": "account/updated", "params": {"authMode": None}})
        send({"id": -99, "result": {"account": None}})
        reply(account, {"account": {"type": "chatgpt", "email": "fixture@example.com", "planType": "plus"},
                        "requiresOpenaiAuth": True})
        limits = receive("account/rateLimits/read")
        assert limits["params"] == {}
        if mode == "outboundLimit":
            send({"id": "x" * 65536, "method": "account/chatgptAuthTokens/refresh", "params": {}})
            sys.stdin.read()
            sys.exit(0)
        # A server-initiated request is refused, never executed.
        send({"id": "server-request", "method": "account/chatgptAuthTokens/refresh", "params": {}})
        rejected = json.loads(sys.stdin.readline())
        assert rejected["id"] == "server-request" and rejected["error"]["code"] == -32601
        primary = {"usedPercent": 25, "windowDurationMins": 300, "resetsAt": 1800000000}
        if mode == "invalidPercent": primary["usedPercent"] = 101
        if mode == "invalidWindow": primary["windowDurationMins"] = -1
        bucket = {"limitId": "codex", "primary": primary,
                  "secondary": {"usedPercent": 73, "windowDurationMins": 10080, "resetsAt": None},
                  "planType": "plus"}
        if mode == "durations":
            bucket["primary"]["windowDurationMins"] = 90
            bucket["secondary"]["windowDurationMins"] = 1440
        result = {"rateLimits": bucket}
        if mode == "multi":
            result["rateLimitsByLimitId"] = {
                "review": {"limitName": "Review", "primary": {"usedPercent": 12}},
                "codex": {"limitName": "Codex",
                          "primary": {"usedPercent": 40, "windowDurationMins": 300},
                          "secondary": {"usedPercent": 80, "windowDurationMins": 10080}}}
        reply(limits, result)
        sys.stdin.read()
        """
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        if mode == "blocked" {
            guard mkfifo(signal.path, 0o600) == 0 else { throw CocoaError(.fileWriteUnknown) }
        }
    }

    func client(deadline: Duration = .seconds(20)) -> CodexClient {
        CodexClient(executablePath: executable.path, home: directory, deadline: deadline)
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}

#if CODEX_STANDALONE_TESTS
// Focused runner: compiles only Usage.swift and these two allowed adapter files.
@main enum CodexFocusedRunner {
    static func main() async {
        let status: CInt = await Testing.__swiftPMEntryPoint()
        exit(status)
    }
}
#endif
