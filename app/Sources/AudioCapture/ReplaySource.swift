import Foundation
import Shared

public enum ReplayPacing: Sendable {
    case realTime
    case immediate
}

public enum ReplaySourceError: Error, Sendable, Equatable {
    case alreadyRunning
    case missingFixture(String)
    case invalidWaveFile
    case unsupportedWaveFormat
}

public actor ReplaySource: AudioSource, AudioCaptureMetricsService {
    public nonisolated let channel: AudioChannel

    private static let defaultFrameSampleCount = AudioFrame.sampleRate / 50
    private static let defaultOutputBufferLimit = 512

    private let fixture: ReplayFixture
    private let pacing: ReplayPacing
    private let frameSampleCount: Int
    private let outputBufferLimit: Int
    private let fixedStartTimestampNanoseconds: UInt64?
    private let dataLoader: @Sendable (ReplayFixture) throws -> Data

    private var activeSessionID: UUID?
    private var activeBuffer: AudioFrameStreamBuffer?
    private var playbackTask: Task<Void, Never>?
    private var lastMetrics: AudioCaptureMetrics = .zero

    public init(
        fixture: ReplayFixture,
        pacing: ReplayPacing = .realTime,
        startTimestampNanoseconds: UInt64? = nil
    ) {
        self.fixture = fixture
        channel = fixture.channel
        self.pacing = pacing
        frameSampleCount = Self.defaultFrameSampleCount
        outputBufferLimit = Self.defaultOutputBufferLimit
        fixedStartTimestampNanoseconds = startTimestampNanoseconds
        dataLoader = Self.loadBundledFixture
    }

    init(
        fixture: ReplayFixture,
        pacing: ReplayPacing,
        frameSampleCount: Int = ReplaySource.defaultFrameSampleCount,
        outputBufferLimit: Int = ReplaySource.defaultOutputBufferLimit,
        startTimestampNanoseconds: UInt64? = nil,
        dataLoader: @escaping @Sendable (ReplayFixture) throws -> Data
    ) {
        precondition(frameSampleCount > 0)
        precondition(outputBufferLimit > 0)
        self.fixture = fixture
        channel = fixture.channel
        self.pacing = pacing
        self.frameSampleCount = frameSampleCount
        self.outputBufferLimit = outputBufferLimit
        fixedStartTimestampNanoseconds = startTimestampNanoseconds
        self.dataLoader = dataLoader
    }

    public func availability() async -> ServiceAvailability {
        do {
            _ = try Self.decodeWave(dataLoader(fixture))
            return .ready
        } catch {
            return .unavailable(.providerFailure)
        }
    }

    public func start() async throws -> AsyncThrowingStream<AudioFrame, Error> {
        guard activeSessionID == nil else { throw ReplaySourceError.alreadyRunning }
        let pcm16 = try Self.decodeWave(dataLoader(fixture))
        let sessionID = UUID()
        let buffer = AudioFrameStreamBuffer(limit: outputBufferLimit)
        let startTimestamp = fixedStartTimestampNanoseconds ?? DispatchTime.now().uptimeNanoseconds

        activeSessionID = sessionID
        activeBuffer = buffer
        buffer.onTermination { [weak self] in
            Task { await self?.stop(sessionID: sessionID) }
        }
        playbackTask = Task { [weak self] in
            await self?.play(
                pcm16: pcm16,
                startTimestampNanoseconds: startTimestamp,
                sessionID: sessionID
            )
        }
        return buffer.stream
    }

    public func stop() async {
        stop(sessionID: activeSessionID)
    }

    public func captureMetrics() async -> AudioCaptureMetrics {
        activeBuffer?.metrics() ?? lastMetrics
    }

    private func play(
        pcm16: Data,
        startTimestampNanoseconds: UInt64,
        sessionID: UUID
    ) async {
        let frameByteCount = frameSampleCount * AudioFrame.bytesPerSample
        let clock = ContinuousClock()
        let playbackStart = clock.now
        var byteOffset = 0
        do {
            while byteOffset < pcm16.count {
                try Task.checkCancellation()
                guard activeSessionID == sessionID, let buffer = activeBuffer else { return }
                let endOffset = min(byteOffset + frameByteCount, pcm16.count)
                let sampleOffset = byteOffset / AudioFrame.bytesPerSample
                let timestamp = startTimestampNanoseconds
                    + UInt64(sampleOffset) * 1_000_000_000 / UInt64(AudioFrame.sampleRate)
                let frame = try AudioFrame(
                    channel: channel,
                    timestampNanoseconds: timestamp,
                    pcm16: pcm16.subdata(in: byteOffset ..< endOffset)
                )
                buffer.yield(frame)
                byteOffset = endOffset
                if pacing == .realTime, byteOffset < pcm16.count {
                    let nextSampleOffset = byteOffset / AudioFrame.bytesPerSample
                    let wholeSeconds = nextSampleOffset / AudioFrame.sampleRate
                    let remainingSamples = nextSampleOffset % AudioFrame.sampleRate
                    let elapsedNanoseconds = Int64(wholeSeconds) * 1_000_000_000
                        + Int64(remainingSamples) * 1_000_000_000 / Int64(AudioFrame.sampleRate)
                    try await clock.sleep(
                        until: playbackStart.advanced(by: .nanoseconds(elapsedNanoseconds))
                    )
                }
            }
            finish(sessionID: sessionID, error: nil)
        } catch is CancellationError {
            return
        } catch {
            finish(sessionID: sessionID, error: error)
        }
    }

    private func stop(sessionID: UUID?) {
        guard let sessionID, activeSessionID == sessionID else { return }
        playbackTask?.cancel()
        finish(sessionID: sessionID, error: nil)
    }

    private func finish(sessionID: UUID, error: Error?) {
        guard activeSessionID == sessionID, let buffer = activeBuffer else { return }
        lastMetrics = buffer.metrics()
        activeSessionID = nil
        activeBuffer = nil
        playbackTask = nil
        buffer.finish(throwing: error)
    }

    private static func loadBundledFixture(_ fixture: ReplayFixture) throws -> Data {
        guard let url = Bundle.module.url(forResource: fixture.resourceName, withExtension: "wav") else {
            throw ReplaySourceError.missingFixture(fixture.id)
        }
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }

    private static func decodeWave(_ data: Data) throws -> Data {
        guard data.count >= 12,
              String(data: data[0 ..< 4], encoding: .ascii) == "RIFF",
              String(data: data[8 ..< 12], encoding: .ascii) == "WAVE"
        else { throw ReplaySourceError.invalidWaveFile }

        var formatIsSupported = false
        var audioData: Data?
        var offset = 12
        while offset + 8 <= data.count {
            let chunkID = String(data: data[offset ..< offset + 4], encoding: .ascii)
            let chunkSize = Int(readUInt32(data, at: offset + 4))
            let contentStart = offset + 8
            guard chunkSize >= 0, contentStart <= data.count, chunkSize <= data.count - contentStart else {
                throw ReplaySourceError.invalidWaveFile
            }
            let contentEnd = contentStart + chunkSize
            if chunkID == "fmt " {
                guard chunkSize >= 16 else { throw ReplaySourceError.invalidWaveFile }
                formatIsSupported = readUInt16(data, at: contentStart) == 1
                    && readUInt16(data, at: contentStart + 2) == 1
                    && readUInt32(data, at: contentStart + 4) == UInt32(AudioFrame.sampleRate)
                    && readUInt16(data, at: contentStart + 12) == UInt16(AudioFrame.bytesPerSample)
                    && readUInt16(data, at: contentStart + 14) == 16
            } else if chunkID == "data" {
                audioData = data.subdata(in: contentStart ..< contentEnd)
            }
            let padding = chunkSize.isMultiple(of: 2) ? 0 : 1
            guard contentEnd <= Int.max - padding else { throw ReplaySourceError.invalidWaveFile }
            offset = contentEnd + padding
        }

        guard formatIsSupported else { throw ReplaySourceError.unsupportedWaveFormat }
        guard let audioData, !audioData.isEmpty, audioData.count.isMultiple(of: AudioFrame.bytesPerSample) else {
            throw ReplaySourceError.invalidWaveFile
        }
        return audioData
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }
}
