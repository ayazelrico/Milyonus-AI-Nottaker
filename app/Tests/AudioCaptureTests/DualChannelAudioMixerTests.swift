@testable import AudioCapture
import Foundation
import Shared
import Testing

struct DualChannelAudioMixerTests {
    @Test func mergesChannelsAndTracksDriftWithoutChangingFrames() async throws {
        let microphone = ControlledAudioSource(channel: .microphone)
        let system = ControlledAudioSource(channel: .system)
        let mixer = DualChannelAudioMixer(microphoneSource: microphone, systemSource: system)
        let stream = try await mixer.start()
        var iterator = stream.makeAsyncIterator()

        let microphoneFrame = try frame(channel: .microphone, timestamp: 1_000_000_000)
        microphone.emit(microphoneFrame)
        #expect(try await iterator.next() == microphoneFrame)

        let systemFrame = try frame(channel: .system, timestamp: 1_010_000_000)
        system.emit(systemFrame)
        #expect(try await iterator.next() == systemFrame)

        var metrics = await mixer.synchronizationMetrics()
        #expect(metrics.currentDriftNanoseconds == 10_000_000)
        #expect(metrics.peakDriftNanoseconds == 10_000_000)
        #expect(metrics.driftViolationCount == 0)

        let lateMicrophoneFrame = try frame(channel: .microphone, timestamp: 1_200_000_000)
        microphone.emit(lateMicrophoneFrame)
        #expect(try await iterator.next() == lateMicrophoneFrame)

        metrics = await mixer.synchronizationMetrics()
        #expect(metrics.currentDriftNanoseconds == 190_000_000)
        #expect(metrics.peakDriftNanoseconds == 190_000_000)
        #expect(metrics.driftViolationCount == 1)
        await mixer.stop()
    }

    @Test func recordsTimestampRegressionAsDiscontinuity() async throws {
        let microphone = ControlledAudioSource(channel: .microphone)
        let system = ControlledAudioSource(channel: .system)
        let mixer = DualChannelAudioMixer(microphoneSource: microphone, systemSource: system)
        let stream = try await mixer.start()
        var iterator = stream.makeAsyncIterator()

        try microphone.emit(frame(channel: .microphone, timestamp: 200_000_000))
        _ = try await iterator.next()
        try microphone.emit(frame(channel: .microphone, timestamp: 100_000_000))
        _ = try await iterator.next()

        #expect(await mixer.synchronizationMetrics().timestampDiscontinuityCount == 1)
        await mixer.stop()
    }

    @Test func combinedOutputIsBoundedAndReportsDrops() async throws {
        let microphone = ControlledAudioSource(channel: .microphone)
        let system = ControlledAudioSource(channel: .system)
        let mixer = DualChannelAudioMixer(
            microphoneSource: microphone,
            systemSource: system,
            outputBufferLimit: 1
        )
        let stream = try await mixer.start()

        try microphone.emit(frame(channel: .microphone, timestamp: 1))
        try microphone.emit(frame(channel: .microphone, timestamp: 2))
        try microphone.emit(frame(channel: .microphone, timestamp: 3))
        try await waitForDeliveredFrames(3, mixer: mixer)

        let metrics = await mixer.synchronizationMetrics()
        #expect(metrics.deliveredFrameCount == 3)
        #expect(metrics.droppedFrameCount == 2)
        _ = stream
        await mixer.stop()
    }

    @Test func feedsRollingBufferWhileDeliveringMixedFrames() async throws {
        let microphone = ControlledAudioSource(channel: .microphone)
        let system = ControlledAudioSource(channel: .system)
        let rollingBuffer = RollingAudioBuffer()
        let mixer = DualChannelAudioMixer(
            microphoneSource: microphone,
            systemSource: system,
            rollingBuffer: rollingBuffer
        )
        let stream = try await mixer.start()
        var iterator = stream.makeAsyncIterator()
        let frame = try frame(channel: .microphone, timestamp: 1_000_000_000)

        microphone.emit(frame)
        #expect(try await iterator.next() == frame)
        #expect(await rollingBuffer.frames(after: 0, channel: .microphone) == [frame])
        await mixer.stop()
    }

    @Test func rejectsSecondSessionAndStopsBothSourcesTogether() async throws {
        let microphone = ControlledAudioSource(channel: .microphone)
        let system = ControlledAudioSource(channel: .system)
        let mixer = DualChannelAudioMixer(microphoneSource: microphone, systemSource: system)
        let stream = try await mixer.start()

        do {
            _ = try await mixer.start()
            Issue.record("Expected already-running error")
        } catch {
            #expect(error as? AudioMixerError == .alreadyRunning)
        }

        await mixer.stop()
        #expect(microphone.stopCount == 1)
        #expect(system.stopCount == 1)
        _ = stream
    }

    @Test func stopsMicrophoneWhenSystemSourceCannotStart() async {
        let microphone = ControlledAudioSource(channel: .microphone)
        let system = ControlledAudioSource(channel: .system, startError: TestSourceError.startFailed)
        let mixer = DualChannelAudioMixer(microphoneSource: microphone, systemSource: system)

        do {
            _ = try await mixer.start()
            Issue.record("Expected system startup failure")
        } catch {
            #expect(error as? TestSourceError == .startFailed)
        }
        #expect(microphone.stopCount == 1)
        #expect(system.stopCount == 1)
    }

    @Test func unexpectedSourceEndFailsTheCombinedSession() async throws {
        let microphone = ControlledAudioSource(channel: .microphone)
        let system = ControlledAudioSource(channel: .system)
        let mixer = DualChannelAudioMixer(microphoneSource: microphone, systemSource: system)
        let stream = try await mixer.start()
        var iterator = stream.makeAsyncIterator()

        system.finish()

        do {
            _ = try await iterator.next()
            Issue.record("Expected source-ended error")
        } catch {
            #expect(error as? AudioMixerError == .sourceEnded(.system))
        }
    }

    @Test func failsSessionWhenSourceEmitsWrongChannel() async throws {
        let microphone = ControlledAudioSource(channel: .microphone)
        let system = ControlledAudioSource(channel: .system)
        let mixer = DualChannelAudioMixer(microphoneSource: microphone, systemSource: system)
        let stream = try await mixer.start()
        var iterator = stream.makeAsyncIterator()

        try microphone.emit(frame(channel: .system, timestamp: 1))

        do {
            _ = try await iterator.next()
            Issue.record("Expected channel validation failure")
        } catch {
            #expect(error as? AudioMixerError == .invalidSourceChannel(
                expected: .microphone,
                actual: .system
            ))
        }
        #expect(microphone.stopCount == 1)
        #expect(system.stopCount == 1)
    }

    private func frame(channel: AudioChannel, timestamp: UInt64) throws -> AudioFrame {
        try AudioFrame(channel: channel, timestampNanoseconds: timestamp, pcm16: Data(count: 320))
    }

    private func waitForDeliveredFrames(_ count: UInt64, mixer: DualChannelAudioMixer) async throws {
        for _ in 0 ..< 100 {
            if await mixer.synchronizationMetrics().deliveredFrameCount == count {
                return
            }
            try await Task.sleep(for: .milliseconds(1))
        }
        Issue.record("Timed out waiting for mixed frames")
    }
}

private enum TestSourceError: Error, Sendable {
    case startFailed
}

private final class ControlledAudioSource: AudioSource, @unchecked Sendable {
    let channel: AudioChannel
    private let startError: TestSourceError?
    private let lock = NSLock()
    private var continuation: AsyncThrowingStream<AudioFrame, Error>.Continuation?
    private var stops = 0

    var stopCount: Int {
        lock.withLock { stops }
    }

    init(channel: AudioChannel, startError: TestSourceError? = nil) {
        self.channel = channel
        self.startError = startError
    }

    func availability() async -> ServiceAvailability {
        .ready
    }

    func start() async throws -> AsyncThrowingStream<AudioFrame, Error> {
        if let startError {
            throw startError
        }
        return AsyncThrowingStream { continuation in
            lock.withLock { self.continuation = continuation }
        }
    }

    func stop() async {
        let activeContinuation = lock.withLock { () -> AsyncThrowingStream<AudioFrame, Error>.Continuation? in
            stops += 1
            defer { continuation = nil }
            return continuation
        }
        activeContinuation?.finish()
    }

    func emit(_ frame: AudioFrame) {
        lock.withLock { continuation }?.yield(frame)
    }

    func finish() {
        lock.withLock { continuation }?.finish()
    }
}
