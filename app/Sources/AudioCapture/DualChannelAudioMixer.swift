import Foundation
import Shared

public actor DualChannelAudioMixer: AudioMixerService {
    public static let defaultDriftThresholdNanoseconds: UInt64 = 50_000_000

    private let microphoneSource: any AudioSource
    private let systemSource: any AudioSource
    private let rollingBuffer: (any AudioRollingBuffer)?
    private let outputBufferLimit: Int
    private let driftThresholdNanoseconds: UInt64

    private var activeSessionID: UUID?
    private var activeBuffer: AudioFrameStreamBuffer?
    private var consumptionTasks: [Task<Void, Never>] = []
    private var latestEndTimestamps: [AudioChannel: UInt64] = [:]
    private var lastStartTimestamps: [AudioChannel: UInt64] = [:]
    private var currentDriftNanoseconds: UInt64?
    private var peakDriftNanoseconds: UInt64 = 0
    private var driftViolationCount: UInt64 = 0
    private var timestampDiscontinuityCount: UInt64 = 0
    private var lastMetrics: AudioSynchronizationMetrics = .zero

    public init(
        microphoneSource: any AudioSource,
        systemSource: any AudioSource,
        outputBufferLimit: Int = 64,
        driftThresholdNanoseconds: UInt64 = DualChannelAudioMixer.defaultDriftThresholdNanoseconds,
        rollingBuffer: (any AudioRollingBuffer)? = nil
    ) {
        precondition(outputBufferLimit > 0)
        precondition(driftThresholdNanoseconds > 0)
        self.microphoneSource = microphoneSource
        self.systemSource = systemSource
        self.outputBufferLimit = outputBufferLimit
        self.driftThresholdNanoseconds = driftThresholdNanoseconds
        self.rollingBuffer = rollingBuffer
    }

    public func start() async throws -> AsyncThrowingStream<AudioFrame, Error> {
        guard activeSessionID == nil else { throw AudioMixerError.alreadyRunning }
        try validateSourceChannels()

        let microphoneStream = try await microphoneSource.start()
        let systemStream: AsyncThrowingStream<AudioFrame, Error>
        do {
            systemStream = try await systemSource.start()
        } catch {
            await microphoneSource.stop()
            await systemSource.stop()
            throw error
        }

        let sessionID = UUID()
        let buffer = AudioFrameStreamBuffer(limit: outputBufferLimit)
        resetMetrics()
        activeSessionID = sessionID
        activeBuffer = buffer
        buffer.onTermination { [weak self] in
            Task { await self?.stop(sessionID: sessionID) }
        }

        consumptionTasks = [
            Task { [weak self] in
                await self?.consume(microphoneStream, expectedChannel: .microphone, sessionID: sessionID)
            },
            Task { [weak self] in
                await self?.consume(systemStream, expectedChannel: .system, sessionID: sessionID)
            },
        ]
        return buffer.stream
    }

    public func stop() async {
        await stop(sessionID: activeSessionID)
    }

    public func synchronizationMetrics() async -> AudioSynchronizationMetrics {
        guard let buffer = activeBuffer else { return lastMetrics }
        return metrics(bufferMetrics: buffer.metrics())
    }

    private func validateSourceChannels() throws {
        guard microphoneSource.channel == .microphone else {
            throw AudioMixerError.invalidSourceChannel(
                expected: .microphone,
                actual: microphoneSource.channel
            )
        }
        guard systemSource.channel == .system else {
            throw AudioMixerError.invalidSourceChannel(
                expected: .system,
                actual: systemSource.channel
            )
        }
    }

    private func consume(
        _ stream: AsyncThrowingStream<AudioFrame, Error>,
        expectedChannel: AudioChannel,
        sessionID: UUID
    ) async {
        do {
            for try await frame in stream {
                guard !Task.isCancelled else { return }
                try await receive(frame, expectedChannel: expectedChannel, sessionID: sessionID)
            }
            await finish(
                sessionID: sessionID,
                error: AudioMixerError.sourceEnded(expectedChannel)
            )
        } catch is CancellationError {
            return
        } catch {
            await finish(sessionID: sessionID, error: error)
        }
    }

    private func receive(
        _ frame: AudioFrame,
        expectedChannel: AudioChannel,
        sessionID: UUID
    ) async throws {
        guard activeSessionID == sessionID, let buffer = activeBuffer else { return }
        guard frame.channel == expectedChannel else {
            throw AudioMixerError.invalidSourceChannel(expected: expectedChannel, actual: frame.channel)
        }

        let timestampRegressed = lastStartTimestamps[frame.channel]
            .map { frame.timestampNanoseconds < $0 } ?? false
        if timestampRegressed {
            timestampDiscontinuityCount += 1
        }
        lastStartTimestamps[frame.channel] = frame.timestampNanoseconds
        latestEndTimestamps[frame.channel] = frame.endTimestampNanoseconds
        updateDrift()
        await rollingBuffer?.append(frame)
        buffer.yield(frame)
    }

    private func updateDrift() {
        guard let microphoneTimestamp = latestEndTimestamps[.microphone],
              let systemTimestamp = latestEndTimestamps[.system]
        else { return }
        let drift = microphoneTimestamp >= systemTimestamp
            ? microphoneTimestamp - systemTimestamp
            : systemTimestamp - microphoneTimestamp
        currentDriftNanoseconds = drift
        peakDriftNanoseconds = max(peakDriftNanoseconds, drift)
        if drift > driftThresholdNanoseconds {
            driftViolationCount += 1
        }
    }

    private func stop(sessionID: UUID?) async {
        guard let sessionID, activeSessionID == sessionID else { return }
        await finish(sessionID: sessionID, error: nil)
    }

    private func finish(sessionID: UUID, error: Error?) async {
        guard activeSessionID == sessionID, let buffer = activeBuffer else { return }
        lastMetrics = metrics(bufferMetrics: buffer.metrics())
        let tasks = consumptionTasks
        activeSessionID = nil
        activeBuffer = nil
        consumptionTasks = []
        tasks.forEach { $0.cancel() }
        await microphoneSource.stop()
        await systemSource.stop()
        buffer.finish(throwing: error)
    }

    private func resetMetrics() {
        latestEndTimestamps = [:]
        lastStartTimestamps = [:]
        currentDriftNanoseconds = nil
        peakDriftNanoseconds = 0
        driftViolationCount = 0
        timestampDiscontinuityCount = 0
        lastMetrics = .zero
    }

    private func metrics(bufferMetrics: AudioCaptureMetrics) -> AudioSynchronizationMetrics {
        AudioSynchronizationMetrics(
            currentDriftNanoseconds: currentDriftNanoseconds,
            peakDriftNanoseconds: peakDriftNanoseconds,
            driftViolationCount: driftViolationCount,
            timestampDiscontinuityCount: timestampDiscontinuityCount,
            deliveredFrameCount: bufferMetrics.deliveredFrameCount,
            droppedFrameCount: bufferMetrics.droppedFrameCount
        )
    }
}
