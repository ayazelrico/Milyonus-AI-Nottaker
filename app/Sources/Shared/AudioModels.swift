import Foundation

public enum AudioChannel: String, Sendable, Codable, CaseIterable {
    case microphone
    case system
}

public struct AudioInputDevice: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let isDefault: Bool

    public init(id: String, name: String, isDefault: Bool) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
    }
}

public struct AudioCaptureMetrics: Sendable, Equatable {
    public let deliveredFrameCount: UInt64
    public let droppedFrameCount: UInt64
    public let restartCount: UInt64

    public init(deliveredFrameCount: UInt64, droppedFrameCount: UInt64, restartCount: UInt64) {
        self.deliveredFrameCount = deliveredFrameCount
        self.droppedFrameCount = droppedFrameCount
        self.restartCount = restartCount
    }

    public static let zero = AudioCaptureMetrics(
        deliveredFrameCount: 0,
        droppedFrameCount: 0,
        restartCount: 0
    )
}

/// Mono, signed PCM16, little-endian audio at 16 kHz. Timestamps use a shared monotonic clock.
public struct AudioFrame: Sendable, Equatable {
    public static let sampleRate = 16000
    public static let bytesPerSample = 2

    public let channel: AudioChannel
    public let timestampNanoseconds: UInt64
    public let pcm16: Data

    public var sampleCount: Int {
        pcm16.count / Self.bytesPerSample
    }

    public var durationSeconds: TimeInterval {
        Double(sampleCount) / Double(Self.sampleRate)
    }

    public init(channel: AudioChannel, timestampNanoseconds: UInt64, pcm16: Data) throws {
        guard !pcm16.isEmpty else { throw DomainValidationError.emptyAudioFrame }
        guard pcm16.count.isMultiple(of: Self.bytesPerSample) else {
            throw DomainValidationError.incompletePCM16Sample
        }
        self.channel = channel
        self.timestampNanoseconds = timestampNanoseconds
        self.pcm16 = pcm16
    }
}

public struct TranscriptSegment: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let meetingID: UUID
    public let channel: AudioChannel
    public let text: String
    public let startMilliseconds: Int
    public let endMilliseconds: Int
    public let isFinal: Bool

    public init(
        id: UUID = UUID(),
        meetingID: UUID,
        channel: AudioChannel,
        text: String,
        startMilliseconds: Int,
        endMilliseconds: Int,
        isFinal: Bool
    ) throws {
        guard startMilliseconds >= 0, endMilliseconds >= startMilliseconds else {
            throw DomainValidationError.invalidTranscriptRange
        }
        self.id = id
        self.meetingID = meetingID
        self.channel = channel
        self.text = text
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
        self.isFinal = isFinal
    }
}
