import Foundation
import Shared

public actor DeepgramTranscriptionService: TranscriptionService {
    public typealias BackoffSleep = @Sendable (Duration) async throws -> Void

    private let tokenProvider: any STTTokenProvider
    private let socketFactory: any DeepgramSocketFactory
    private let backoffSleep: BackoffSleep
    private var sessions: [UUID: Task<Void, Never>] = [:]
    private var channels: [AudioChannel: UUID] = [:]

    public init(
        tokenProvider: any STTTokenProvider,
        socketFactory: any DeepgramSocketFactory = URLSessionDeepgramSocketFactory(),
        backoffSleep: @escaping BackoffSleep = { duration in
            try await Task.sleep(for: duration)
        }
    ) {
        self.tokenProvider = tokenProvider
        self.socketFactory = socketFactory
        self.backoffSleep = backoffSleep
    }

    public func availability() async -> ServiceAvailability {
        .ready
    }

    public func transcribe(
        meetingID: UUID,
        frames: AsyncThrowingStream<AudioFrame, Error>,
        language: AppLanguage
    ) async throws -> AsyncThrowingStream<TranscriptSegment, Error> {
        let sessionID = UUID()
        let tokenProvider = tokenProvider
        let socketFactory = socketFactory
        let backoffSleep = backoffSleep
        let service = self
        var storedContinuation: AsyncThrowingStream<TranscriptSegment, Error>.Continuation?
        let stream = AsyncThrowingStream<TranscriptSegment, Error>(bufferingPolicy: .bufferingNewest(128)) {
            storedContinuation = $0
        }
        guard let continuation = storedContinuation else {
            throw TranscriptionError.connectionClosed
        }

        let task = Task {
            let runner = DeepgramSessionRunner(
                meetingID: meetingID,
                language: language,
                tokenProvider: tokenProvider,
                socketFactory: socketFactory,
                backoffSleep: backoffSleep,
                reserveChannel: { channel in
                    try await service.reserve(channel: channel, for: sessionID)
                }
            )
            do {
                try await runner.run(frames: frames, output: continuation)
                continuation.finish()
            } catch is CancellationError {
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
            await service.removeSession(sessionID)
        }
        sessions[sessionID] = task
        continuation.onTermination = { termination in
            guard case .cancelled = termination else { return }
            Task { await service.cancelSession(sessionID) }
        }
        return stream
    }

    public func stop() async {
        let active = sessions.values
        sessions.removeAll()
        channels.removeAll()
        for task in active {
            task.cancel()
        }
    }

    private func reserve(channel: AudioChannel, for sessionID: UUID) throws {
        if let existing = channels[channel], existing != sessionID {
            throw TranscriptionError.alreadyTranscribingChannel
        }
        channels[channel] = sessionID
    }

    private func removeSession(_ sessionID: UUID) {
        sessions[sessionID] = nil
        channels = channels.filter { $0.value != sessionID }
    }

    private func cancelSession(_ sessionID: UUID) {
        let task = sessions.removeValue(forKey: sessionID)
        channels = channels.filter { $0.value != sessionID }
        task?.cancel()
    }
}

private struct DeepgramConnection: Sendable {
    let socket: any DeepgramSocket
    let generation: Int
    let receiver: Task<Void, Never>
    let keepAlive: Task<Void, Never>

    func close() async {
        receiver.cancel()
        keepAlive.cancel()
        await socket.close()
    }
}

private actor DeepgramConnectionState {
    enum Status {
        case connected
        case failed
        case closed
    }

    private var generation = 0
    private var status: Status = .closed

    func activate() -> Int {
        generation += 1
        status = .connected
        return generation
    }

    func markFailed(generation candidate: Int) {
        guard candidate == generation, status == .connected else { return }
        status = .failed
    }

    func markClosed(generation candidate: Int) {
        guard candidate == generation, status == .connected else { return }
        status = .closed
    }

    func needsReconnect(generation candidate: Int) -> Bool {
        candidate != generation || status != .connected
    }

    func isCurrent(generation candidate: Int) -> Bool {
        candidate == generation
    }
}

private actor DeepgramSocketHolder {
    private var socket: (any DeepgramSocket)?

    func replace(with newSocket: any DeepgramSocket) async {
        let oldSocket = socket
        socket = newSocket
        await oldSocket?.close()
    }

    func close() async {
        let current = socket
        socket = nil
        await current?.close()
    }
}

private struct DeepgramStreamingContext: Sendable {
    let channel: AudioChannel
    let meetingStart: UInt64
    let mapper: DeepgramEventMapper
    let output: AsyncThrowingStream<TranscriptSegment, Error>.Continuation
}

private struct DeepgramSessionRunner: Sendable {
    typealias ReserveChannel = @Sendable (AudioChannel) async throws -> Void

    private let meetingID: UUID
    private let language: AppLanguage
    private let tokenProvider: any STTTokenProvider
    private let socketFactory: any DeepgramSocketFactory
    private let backoffSleep: DeepgramTranscriptionService.BackoffSleep
    private let reserveChannel: ReserveChannel
    private let state = DeepgramConnectionState()
    private let holder = DeepgramSocketHolder()

    init(
        meetingID: UUID,
        language: AppLanguage,
        tokenProvider: any STTTokenProvider,
        socketFactory: any DeepgramSocketFactory,
        backoffSleep: @escaping DeepgramTranscriptionService.BackoffSleep,
        reserveChannel: @escaping ReserveChannel
    ) {
        self.meetingID = meetingID
        self.language = language
        self.tokenProvider = tokenProvider
        self.socketFactory = socketFactory
        self.backoffSleep = backoffSleep
        self.reserveChannel = reserveChannel
    }

    func run(
        frames: AsyncThrowingStream<AudioFrame, Error>,
        output: AsyncThrowingStream<TranscriptSegment, Error>.Continuation
    ) async throws {
        try await withTaskCancellationHandler {
            try await runSession(frames: frames, output: output)
        } onCancel: {
            Task { await holder.close() }
        }
    }

    private func runSession(
        frames: AsyncThrowingStream<AudioFrame, Error>,
        output: AsyncThrowingStream<TranscriptSegment, Error>.Continuation
    ) async throws {
        var iterator = frames.makeAsyncIterator()
        guard let frame = try await iterator.next() else { return }
        let channel = frame.channel
        try await reserveChannel(channel)
        let meetingStart = frame.timestampNanoseconds
        let mapper = DeepgramEventMapper(meetingID: meetingID, channel: channel)
        let context = DeepgramStreamingContext(
            channel: channel,
            meetingStart: meetingStart,
            mapper: mapper,
            output: output
        )
        var connection: DeepgramConnection?
        var failedConnections = 0

        defer {
            connection?.receiver.cancel()
            connection?.keepAlive.cancel()
            Task { await holder.close() }
        }

        connection = try await sendFrames(
            firstFrame: frame,
            iterator: &iterator,
            context: context,
            failedConnections: &failedConnections
        )

        if let connection {
            try? await connection.socket.send(.text("{\"type\":\"CloseStream\"}"))
            try await waitForFinalMessages(generation: connection.generation)
            await connection.close()
        }
    }

    private func sendFrames(
        firstFrame: AudioFrame,
        iterator: inout AsyncThrowingStream<AudioFrame, Error>.Iterator,
        context: DeepgramStreamingContext,
        failedConnections: inout Int
    ) async throws -> DeepgramConnection? {
        var frame = firstFrame
        var connection: DeepgramConnection?
        while true {
            try validate(frame: frame, channel: context.channel, meetingStart: context.meetingStart)
            connection = try await activeConnection(
                connection,
                frame: frame,
                context: context,
                failedConnections: &failedConnections
            )
            guard let activeConnection = connection else { throw TranscriptionError.connectionClosed }
            do {
                try await activeConnection.socket.send(.data(frame.pcm16))
            } catch {
                await state.markFailed(generation: activeConnection.generation)
                continue
            }
            guard let next = try await iterator.next() else { return connection }
            frame = next
        }
    }

    private func activeConnection(
        _ connection: DeepgramConnection?,
        frame: AudioFrame,
        context: DeepgramStreamingContext,
        failedConnections: inout Int
    ) async throws -> DeepgramConnection {
        if let connection {
            let needsReconnect = await state.needsReconnect(generation: connection.generation)
            if !needsReconnect {
                return connection
            }
        }
        if let connection {
            await connection.close()
            failedConnections += 1
        }
        return try await connectWithRetry(
            failedConnections: &failedConnections,
            channelOffsetMilliseconds: Int((frame.timestampNanoseconds - context.meetingStart) / 1_000_000),
            mapper: context.mapper,
            output: context.output
        )
    }

    private func validate(frame: AudioFrame, channel: AudioChannel, meetingStart: UInt64) throws {
        try Task.checkCancellation()
        guard frame.channel == channel else { throw TranscriptionError.channelChanged }
        guard frame.timestampNanoseconds >= meetingStart else {
            throw TranscriptionError.timestampRegression
        }
    }

    private func connectWithRetry(
        failedConnections: inout Int,
        channelOffsetMilliseconds: Int,
        mapper: DeepgramEventMapper,
        output: AsyncThrowingStream<TranscriptSegment, Error>.Continuation
    ) async throws -> DeepgramConnection {
        while true {
            if failedConnections > 3 {
                throw TranscriptionError.reconnectLimitReached
            }
            if failedConnections > 0 {
                let delay = [250, 500, 1000][min(failedConnections - 1, 2)]
                try await backoffSleep(.milliseconds(delay))
            }
            do {
                let token = try await tokenProvider.token(consentConfirmed: true)
                let request = try Self.request(language: language, token: token)
                let socket = try await socketFactory.connect(request: request)
                await holder.replace(with: socket)
                let generation = await state.activate()
                let receiver = receive(
                    socket: socket,
                    generation: generation,
                    channelOffsetMilliseconds: channelOffsetMilliseconds,
                    mapper: mapper,
                    output: output
                )
                let keepAlive = keepAlive(socket: socket, generation: generation)
                return DeepgramConnection(
                    socket: socket,
                    generation: generation,
                    receiver: receiver,
                    keepAlive: keepAlive
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failedConnections += 1
            }
        }
    }

    private func receive(
        socket: any DeepgramSocket,
        generation: Int,
        channelOffsetMilliseconds: Int,
        mapper: DeepgramEventMapper,
        output: AsyncThrowingStream<TranscriptSegment, Error>.Continuation
    ) -> Task<Void, Never> {
        Task {
            do {
                while let message = try await socket.receive() {
                    try Task.checkCancellation()
                    guard await state.isCurrent(generation: generation) else { return }
                    let data: Data = switch message {
                    case let .data(value):
                        value
                    case let .text(value):
                        Data(value.utf8)
                    }
                    if let result = try DeepgramResultsDecoder.decode(
                        data,
                        offsetMilliseconds: channelOffsetMilliseconds
                    ), let segment = try await mapper.map(result) {
                        output.yield(segment)
                    }
                }
                await state.markClosed(generation: generation)
            } catch is CancellationError {
                return
            } catch {
                await state.markFailed(generation: generation)
            }
        }
    }

    private func keepAlive(socket: any DeepgramSocket, generation: Int) -> Task<Void, Never> {
        Task {
            do {
                while true {
                    try await Task.sleep(for: .seconds(5))
                    try Task.checkCancellation()
                    try await socket.send(.text("{\"type\":\"KeepAlive\"}"))
                }
            } catch is CancellationError {
                return
            } catch {
                await state.markFailed(generation: generation)
            }
        }
    }

    private func waitForFinalMessages(generation: Int) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while clock.now < deadline {
            if await state.needsReconnect(generation: generation) {
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private static func request(language: AppLanguage, token: STTAccessToken) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "wss"
        components.host = "api.deepgram.com"
        components.path = "/v1/listen"
        components.queryItems = [
            URLQueryItem(name: "model", value: "nova-3"),
            URLQueryItem(name: "language", value: language == .turkish ? "tr" : "en"),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: "16000"),
            URLQueryItem(name: "channels", value: "1"),
            URLQueryItem(name: "interim_results", value: "true"),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "smart_format", value: "true"),
            URLQueryItem(name: "endpointing", value: "300"),
        ]
        guard let url = components.url else { throw TranscriptionError.connectionClosed }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue(token.authorizationValue(), forHTTPHeaderField: "Authorization")
        return request
    }
}
