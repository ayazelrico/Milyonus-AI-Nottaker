import Foundation
import Shared

/// Keeps a bounded per-channel window so a reconnect can replay audio that was not acknowledged.
public actor RollingAudioBuffer: AudioRollingBuffer {
    public static let defaultWindowNanoseconds: UInt64 = 10_000_000_000

    private let windowNanoseconds: UInt64
    private let maximumFrameCount: Int
    private var framesByChannel: [AudioChannel: [AudioFrame]] = [:]
    private var droppedFrameCount: UInt64 = 0
    private var discontinuityCount: UInt64 = 0

    public init(
        windowNanoseconds: UInt64 = RollingAudioBuffer.defaultWindowNanoseconds,
        maximumFrameCount: Int = 512
    ) {
        precondition(windowNanoseconds > 0)
        precondition(maximumFrameCount > 0)
        self.windowNanoseconds = windowNanoseconds
        self.maximumFrameCount = maximumFrameCount
    }

    public func append(_ frame: AudioFrame) {
        var channelFrames = framesByChannel[frame.channel, default: []]
        if let previous = channelFrames.last {
            if frame.timestampNanoseconds < previous.timestampNanoseconds {
                discontinuityCount += 1
                return
            }
            if frame.timestampNanoseconds < previous.endTimestampNanoseconds {
                discontinuityCount += 1
                return
            }
            if frame.timestampNanoseconds > previous.endTimestampNanoseconds {
                discontinuityCount += 1
            }
        }

        channelFrames.append(frame)
        let cutoff = frame.endTimestampNanoseconds > windowNanoseconds
            ? frame.endTimestampNanoseconds - windowNanoseconds
            : 0
        while let first = channelFrames.first, first.endTimestampNanoseconds <= cutoff {
            channelFrames.removeFirst()
            droppedFrameCount += 1
        }
        while channelFrames.count > maximumFrameCount {
            channelFrames.removeFirst()
            droppedFrameCount += 1
        }
        framesByChannel[frame.channel] = channelFrames
    }

    public func frames(
        after timestampNanoseconds: UInt64,
        channel: AudioChannel
    ) -> [AudioFrame] {
        framesByChannel[channel, default: []].filter {
            $0.endTimestampNanoseconds > timestampNanoseconds
        }
    }

    public func reset() {
        framesByChannel.removeAll()
        droppedFrameCount = 0
        discontinuityCount = 0
    }

    public func metrics() -> AudioRollingBufferMetrics {
        let retained = framesByChannel.values.flatMap(\.self)
        let earliest = retained.map(\.timestampNanoseconds).min()
        let latest = retained.map(\.endTimestampNanoseconds).max()
        let duration: UInt64 = if let earliest, let latest {
            latest >= earliest ? latest - earliest : 0
        } else {
            0
        }
        return AudioRollingBufferMetrics(
            retainedFrameCount: retained.count,
            retainedDurationNanoseconds: duration,
            droppedFrameCount: droppedFrameCount,
            discontinuityCount: discontinuityCount
        )
    }
}
