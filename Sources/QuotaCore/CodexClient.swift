import Foundation
import Darwin

/// One helper per account home. No threads, model turns, or global login state.
public actor CodexClient {
    private let executablePath: String
    private let home: URL
    private let deadline: Duration
    private var transport: CodexTransport?
    private var reader: Task<Void, Never>?
    private var generation = UUID()
    private var nextID = 0
    private var pending: (id: Int, continuation: CheckedContinuation<Data, Error>)?
    private var timer: Task<Void, Never>?
    private var buffer = Data()
    private var busy = false

    public init(executablePath: String, home: URL) {
        self.executablePath = executablePath
        self.home = home
        self.deadline = .seconds(20)
    }

    // A shorter bound for deterministic timeout fixtures.
    init(executablePath: String, home: URL, deadline: Duration) {
        self.executablePath = executablePath
        self.home = home
        self.deadline = deadline
    }

    public func readUsage() async throws -> UsageSnapshot {
        try beginOperation()
        defer { busy = false }
        try await connect()
        let account = try decode(AccountResponse.self, await request(
            "account/read", params: ["refreshToken": true]
        ))
        guard let account = account.account else { throw UsageError.notAuthenticated }
        guard account.type == "chatgpt" else {
            throw UsageError.providerMessage("Usage requires a ChatGPT account.")
        }
        guard let email = account.email, !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw UsageError.invalidPayload
        }
        let response = try decode(LimitsResponse.self, await request("account/rateLimits/read", params: [:]))
        var buckets = response.rateLimitsByLimitId ?? [:]
        let legacyID = response.rateLimits.limitId ?? "codex"
        if buckets[legacyID] == nil { buckets[legacyID] = response.rateLimits }
        var limits: [UsageLimit] = []
        for id in buckets.keys.sorted() {
            guard let bucket = buckets[id] else { continue }
            for (kind, window) in [("primary", bucket.primary), ("secondary", bucket.secondary)] {
                guard let window else { continue }
                if let minutes = window.windowDurationMins, minutes <= 0 { throw UsageError.invalidPayload }
                let duration: String
                if let minutes = window.windowDurationMins {
                    if minutes == 10080 {
                        duration = "주간"
                    } else if minutes.isMultiple(of: 1440) {
                        duration = "\(minutes / 1440)일"
                    } else if minutes.isMultiple(of: 60) {
                        duration = "\(minutes / 60)시간"
                    } else if minutes > 60 {
                        duration = "\(minutes / 60)시간 \(minutes % 60)분"
                    } else {
                        duration = "\(minutes)분"
                    }
                } else {
                    duration = kind == "primary" ? "단기 한도" : "장기 한도"
                }
                limits.append(try UsageLimit(
                    id: "\(id)/\(kind)",
                    title: buckets.count > 1 ? "\(bucket.limitName ?? id) · \(duration)" : duration,
                    usedPercent: window.usedPercent,
                    windowMinutes: window.windowDurationMins,
                    resetsAt: window.resetsAt.map { Date(timeIntervalSince1970: Double($0)) }
                ))
            }
        }
        return UsageSnapshot(identity: email, displayIdentity: email,
                             plan: account.planType ?? response.rateLimits.planType, limits: limits)
    }

    /// Returns immediately after the server starts browser OAuth. Keep this actor alive,
    /// open the URL in the UI, then call readUsage() to verify the completed login.
    public func startLogin() async throws -> URL {
        try beginOperation()
        defer { busy = false }
        try await connect()
        let login = try decode(LoginResponse.self, await request("account/login/start", params: ["type": "chatgpt"]))
        guard login.type == "chatgpt", !login.loginId.isEmpty,
              let url = URL(string: login.authUrl),
              url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "auth.openai.com",
              url.user == nil, url.password == nil,
              url.port == nil || url.port == 443 else {
            throw UsageError.invalidPayload
        }
        return url
    }

    public func shutdown() async {
        let previous = transport
        stop(CancellationError())
        await previous?.finishClosingHandles()
    }

    private func beginOperation() throws {
        try Task.checkCancellation()
        guard !busy else { throw UsageError.providerMessage("A Codex account operation is already running.") }
        busy = true
    }

    private func connect() async throws {
        if transport != nil { return }
        let token = UUID()
        generation = token
        let path = executablePath
        let home = home
        let newTransport = try await Task.detached(priority: .utility) {
            try CodexTransport(executablePath: path, home: home)
        }.value
        guard generation == token, !Task.isCancelled else {
            newTransport.close()
            throw CancellationError()
        }
        transport = newTransport
        reader = Task { [weak self, stream = newTransport.stream] in
            do {
                for try await data in stream {
                    guard let self else { break }
                    await self.receive(data, generation: token)
                }
                await self?.ended(generation: token, error: UsageError.providerMessage("Codex app-server closed stdout."))
            } catch {
                await self?.ended(generation: token, error: error)
            }
        }
        do {
            _ = try await request("initialize", params: [
                "clientInfo": ["name": "quota_usage", "title": "Quota", "version": "1.0"],
                "capabilities": ["experimentalApi": false]
            ])
            try send(["method": "initialized"])
        } catch {
            stop(error)
            throw error
        }
    }

    private func request(_ method: String, params: [String: Any]) async throws -> Data {
        try Task.checkCancellation()
        guard transport != nil else { throw CancellationError() }
        nextID += 1
        let id = nextID
        let token = generation
        let packet = try JSONSerialization.data(withJSONObject: ["id": id, "method": method, "params": params]) + Data([10])
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending = (id, continuation)
                timer = Task { [weak self, deadline] in
                    do { try await Task.sleep(for: deadline) } catch { return }
                    await self?.failRequest(id: id, generation: token, error: UsageError.timedOut)
                }
                transport?.write(packet)
            }
        } onCancel: {
            Task { await self.failRequest(id: id, generation: token, error: CancellationError()) }
        }
    }

    private func send(_ object: [String: Any]) throws {
        let packet = try JSONSerialization.data(withJSONObject: object) + Data([10])
        transport?.write(packet)
    }

    private func receive(_ data: Data, generation token: UUID) {
        guard token == generation else { return }
        buffer.append(data)
        do {
            while let newline = buffer.firstIndex(of: 10) {
                guard newline < 1_048_576 else { throw UsageError.invalidPayload }
                let line = buffer.prefix(upTo: newline)
                buffer.removeSubrange(...newline)
                guard let object = try JSONSerialization.jsonObject(with: line) as? [String: Any] else {
                    throw UsageError.invalidPayload
                }
                if object["method"] != nil {
                    // Notifications are advisory; only explicit reads update snapshots.
                    // Refuse all server requests, including token/approval callbacks.
                    if let id = object["id"] {
                        try send(["id": id, "error": ["code": -32601, "message": "Unsupported method"]])
                    }
                    continue
                }
                guard let id = object["id"] as? Int, id == pending?.id else { continue }
                guard let current = pending else { continue }
                pending = nil
                timer?.cancel()
                timer = nil
                if let error = object["error"] as? [String: Any] {
                    current.continuation.resume(throwing: UsageError.providerMessage(
                        error["message"] as? String ?? "Codex RPC failed."
                    ))
                } else if let result = object["result"] as? [String: Any] {
                    current.continuation.resume(returning: try JSONSerialization.data(withJSONObject: result))
                } else {
                    current.continuation.resume(throwing: UsageError.invalidPayload)
                }
            }
            guard buffer.count < 1_048_576 else { throw UsageError.invalidPayload }
        } catch {
            stop(UsageError.invalidPayload)
        }
    }

    private func ended(generation token: UUID, error: Error) {
        guard token == generation else { return }
        stop(error)
    }

    private func failRequest(id: Int, generation token: UUID, error: Error) {
        guard token == generation, pending?.id == id else { return }
        stop(error)
    }

    private func stop(_ error: Error) {
        generation = UUID()
        timer?.cancel()
        timer = nil
        let current = pending
        pending = nil
        reader?.cancel()
        reader = nil
        transport?.close()
        transport = nil
        buffer.removeAll()
        current?.continuation.resume(throwing: error)
    }

    private func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw UsageError.invalidPayload }
    }

    deinit {
        reader?.cancel()
        timer?.cancel()
        transport?.close()
    }
}

private struct AccountResponse: Decodable {
    let account: AccountPayload?
}
private struct AccountPayload: Decodable {
    let type: String
    let email: String?
    let planType: String?
}
private struct LoginResponse: Decodable {
    let type: String
    let loginId: String
    let authUrl: String
}
private struct LimitsResponse: Decodable {
    let rateLimits: LimitBucket
    let rateLimitsByLimitId: [String: LimitBucket]?
}
private struct LimitBucket: Decodable {
    let limitId: String?
    let limitName: String?
    let primary: LimitWindow?
    let secondary: LimitWindow?
    let planType: String?
}
private struct LimitWindow: Decodable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: Int64?
}

/// File callbacks and writes run off the actor. The serial queue owns all handle
/// closure/write operations; the stream preserves stdout order with a bounded queue.
private final class CodexTransport: @unchecked Sendable {
    let stream: AsyncThrowingStream<Data, Error>
    private let continuation: AsyncThrowingStream<Data, Error>.Continuation
    private let process: Process
    private let input: Pipe
    private let output: Pipe
    private let queue = DispatchQueue(label: "quota.codex.stdio", qos: .utility)
    private let writeLock = NSLock()
    private var queuedBytes = 0
    private var closed = false

    init(executablePath: String, home: URL) throws {
        guard home.isFileURL, home.path.hasPrefix("/"),
              executablePath.hasPrefix("/"),
              FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw UsageError.missingCLI
        }
        let pair = AsyncThrowingStream<Data, Error>.makeStream(bufferingPolicy: .bufferingOldest(64))
        stream = pair.stream
        continuation = pair.continuation
        process = Process()
        input = Pipe()
        output = Pipe()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["app-server"]
        process.currentDirectoryURL = URL(fileURLWithPath: "/", isDirectory: true)
        // Do not inherit API keys, alternate Codex homes, or provider overrides.
        var environment: [String: String] = [:]
        for key in ["PATH", "HOME", "TMPDIR", "LANG", "LC_ALL"] {
            environment[key] = ProcessInfo.processInfo.environment[key]
        }
        environment["CODEX_HOME"] = home.path
        process.environment = environment
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        output.fileHandleForReading.readabilityHandler = { [continuation] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                continuation.finish()
            } else if case .dropped = continuation.yield(data) {
                continuation.finish(throwing: UsageError.invalidPayload)
            }
        }
        do { try process.run() }
        catch {
            output.fileHandleForReading.readabilityHandler = nil
            try? input.fileHandleForWriting.close()
            try? output.fileHandleForReading.close()
            throw UsageError.missingCLI
        }
        // Parent copies of the child's ends must not keep EOF from arriving.
        try? input.fileHandleForReading.close()
        try? output.fileHandleForWriting.close()
    }

    func write(_ data: Data) {
        writeLock.lock()
        guard queuedBytes + data.count <= 65_536 else {
            writeLock.unlock()
            continuation.finish(throwing: UsageError.invalidPayload)
            return
        }
        queuedBytes += data.count
        writeLock.unlock()
        queue.async { [self] in
            defer {
                writeLock.lock()
                queuedBytes -= data.count
                writeLock.unlock()
            }
            guard !closed else { return }
            do { try input.fileHandleForWriting.write(contentsOf: data) }
            catch { continuation.finish(throwing: error) }
        }
    }

    func close() {
        // Kill before queueing closure: a hostile peer cannot block cleanup by
        // refusing to drain stdin. Foundation reaps the process asynchronously.
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        queue.async { [self] in
            guard !closed else { return }
            closed = true
            output.fileHandleForReading.readabilityHandler = nil
            try? input.fileHandleForWriting.close()
            try? output.fileHandleForReading.close()
            continuation.finish()
        }
    }

    func finishClosingHandles() async {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume() }
        }
    }
}
