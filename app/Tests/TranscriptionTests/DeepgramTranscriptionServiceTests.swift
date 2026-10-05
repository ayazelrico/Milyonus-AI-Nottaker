import Foundation
import Shared
import Testing
@testable import Transcription

@Suite("Deepgram transcription service")
struct DeepgramTranscriptionServiceTests {
    @Test func streamsPCMAndMapsProviderResultsForTheSelectedLanguage() async throws {
        let providerMessage = try resultJSON(text: "Merhaba", start: 0.1, duration: 0.4, isFinal: true)
        let socket = FakeSocket(messages: [.data(providerMessage)])
        let factory = FakeSocketFactory(sockets: [socket])
        let tokenProvider = FakeTokenProvider()
        let service = DeepgramTranscriptionService(
            tokenProvider: tokenProvider,
            socketFactory: factory,
            backoffSleep: { _ in }
        )
        let meetingID = UUID()
        let frame = try AudioFrame(
            channel: .system,
            timestampNanoseconds: 5_000_000_000,
            pcm16: Data(repeating: 7, count: 640)
        )

        let output = try await service.transcribe(
            meetingID: meetingID,
            frames: frameStream([frame]),
            language: .turkish
        )
        var segments: [TranscriptSegment] = []
        for try await segment in output {
            segments.append(segment)
        }

        let segment = try #require(segments.first)
        #expect(segment.meetingID == meetingID)
        #expect(segment.channel == .system)
        #expect(segment.text == "Merhaba")
        #expect(segment.startMilliseconds == 100)
        #expect(segment.endMilliseconds == 500)
        #expect(segment.isFinal)
        let request = try #require(await factory.requests.first)
        let requestURL = try #require(request.url)
        let components = try #require(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(components.scheme == "wss")
        #expect(components.host == "api.deepgram.com")
        #expect(components.path == "/v1/listen")
        #expect(query["model"] == "nova-3")
        #expect(query["language"] == "tr")
        #expect(query["encoding"] == "linear16")
        #expect(query["sample_rate"] == "16000")
        #expect(query["interim_results"] == "true")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer header.payload.signature")
        #expect(await socket.sentMessages.contains(.data(frame.pcm16)))
        #expect(await tokenProvider.requestCount == 1)
    }

    @Test func refreshesTheTokenAndBacksOffBeforeReconnect() async throws {
        let first = FakeSocket(messages: [], dataSendFailures: 1)
        let second = FakeSocket(messages: [])
        let factory = FakeSocketFactory(sockets: [first, second])
        let tokenProvider = FakeTokenProvider()
        let delays = DelayRecorder()
        let service = DeepgramTranscriptionService(
            tokenProvider: tokenProvider,
            socketFactory: factory,
            backoffSleep: { duration in await delays.append(duration) }
        )
        let frame = try AudioFrame(
            channel: .microphone,
            timestampNanoseconds: 10,
            pcm16: Data(repeating: 1, count: 640)
        )

        let output = try await service.transcribe(
            meetingID: UUID(),
            frames: frameStream([frame]),
            language: .english
        )
        for try await _ in output {}

        #expect(await tokenProvider.requestCount == 2)
        #expect(await factory.requests.count == 2)
        #expect(await delays.values == [.milliseconds(250)])
        #expect(await second.sentMessages.contains(.data(frame.pcm16)))
    }

    @Test func rejectsAChannelChangeAndStopsAllActiveWork() async throws {
        let socket = FakeSocket(messages: [])
        let service = DeepgramTranscriptionService(
            tokenProvider: FakeTokenProvider(),
            socketFactory: FakeSocketFactory(sockets: [socket]),
            backoffSleep: { _ in }
        )
        let microphone = try AudioFrame(
            channel: .microphone,
            timestampNanoseconds: 0,
            pcm16: Data(repeating: 1, count: 640)
        )
        let system = try AudioFrame(
            channel: .system,
            timestampNanoseconds: 20_000_000,
            pcm16: Data(repeating: 2, count: 640)
        )

        let output = try await service.transcribe(
            meetingID: UUID(),
            frames: frameStream([microphone, system]),
            language: .english
        )
        await #expect(throws: TranscriptionError.channelChanged) {
            for try await _ in output {}
        }
        await service.stop()
        #expect(await socket.closeCount >= 1)
    }

    @Test func rejectsASecondSessionForTheSameActiveChannel() async throws {
        let firstSocket = FakeSocket(messages: [])
        let tokenProvider = FakeTokenProvider()
        let service = DeepgramTranscriptionService(
            tokenProvider: tokenProvider,
            socketFactory: FakeSocketFactory(sockets: [firstSocket]),
            backoffSleep: { _ in }
        )
        let frame = try AudioFrame(
            channel: .microphone,
            timestampNanoseconds: 0,
            pcm16: Data(repeating: 1, count: 640)
        )
        var firstContinuation: AsyncThrowingStream<AudioFrame, Error>.Continuation?
        let firstFrames = AsyncThrowingStream<AudioFrame, Error> { firstContinuation = $0 }
        let continuation = try #require(firstContinuation)
        continuation.yield(frame)
        let firstOutput = try await service.transcribe(
            meetingID: UUID(),
            frames: firstFrames,
            language: .english
        )
        try await waitUntil { await tokenProvider.requestCount == 1 }

        let secondOutput = try await service.transcribe(
            meetingID: UUID(),
            frames: frameStream([frame]),
            language: .english
        )
        await #expect(throws: TranscriptionError.alreadyTranscribingChannel) {
            for try await _ in secondOutput {}
        }
        #expect(await tokenProvider.requestCount == 1)

        continuation.finish()
        for try await _ in firstOutput {}
    }

    private func frameStream(_ frames: [AudioFrame]) -> AsyncThrowingStream<AudioFrame, Error> {
        AsyncThrowingStream { continuation in
            for frame in frames {
                continuation.yield(frame)
            }
            continuation.finish()
        }
    }

    private func resultJSON(text: String, start: Double, duration: Double, isFinal: Bool) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "type": "Results",
            "start": start,
            "duration": duration,
            "is_final": isFinal,
            "channel": ["alternatives": [["transcript": text]]],
        ])
    }

    private func waitUntil(_ condition: @escaping @Sendable () async -> Bool) async throws {
        for _ in 0 ..< 100 {
            if await condition() {
                return
            }
            await Task.yield()
        }
        throw TranscriptionError.connectionClosed
    }
}

private actor FakeTokenProvider: STTTokenProvider {
    private(set) var requestCount = 0

    func token(consentConfirmed: Bool) async throws -> STTAccessToken {
        #expect(consentConfirmed)
        requestCount += 1
        return try STTAccessToken(value: "header.payload.signature", expiresIn: 30)
    }
}

private actor FakeSocketFactory: DeepgramSocketFactory {
    private var sockets: [FakeSocket]
    private(set) var requests: [URLRequest] = []

    init(sockets: [FakeSocket]) {
        self.sockets = sockets
    }

    func connect(request: URLRequest) async throws -> any DeepgramSocket {
        requests.append(request)
        guard !sockets.isEmpty else { throw TranscriptionError.connectionClosed }
        return sockets.removeFirst()
    }
}

private actor FakeSocket: DeepgramSocket {
    private var messages: [DeepgramSocketMessage]
    private var dataSendFailures: Int
    private(set) var sentMessages: [DeepgramSocketMessage] = []
    private(set) var closeCount = 0

    init(messages: [DeepgramSocketMessage], dataSendFailures: Int = 0) {
        self.messages = messages
        self.dataSendFailures = dataSendFailures
    }

    func send(_ message: DeepgramSocketMessage) async throws {
        if case .data = message, dataSendFailures > 0 {
            dataSendFailures -= 1
            throw TranscriptionError.connectionClosed
        }
        sentMessages.append(message)
    }

    func receive() async throws -> DeepgramSocketMessage? {
        guard !messages.isEmpty else { return nil }
        return messages.removeFirst()
    }

    func close() async {
        closeCount += 1
    }
}

private actor DelayRecorder {
    private(set) var values: [Duration] = []

    func append(_ duration: Duration) {
        values.append(duration)
    }
}
