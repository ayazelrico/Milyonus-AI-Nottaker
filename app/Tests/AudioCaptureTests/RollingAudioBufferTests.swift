@testable import AudioCapture
import Foundation
import Shared
import Testing

struct RollingAudioBufferTests {
    @Test func retainsFramesByChannelAndReturnsFramesAfterWatermark() async throws {
        let buffer = RollingAudioBuffer(windowNanoseconds: 1_000_000_000)
        let first = try frame(channel: .microphone, timestamp: 1_000_000_000, samples: 80)
        let second = try frame(channel: .microphone, timestamp: 1_005_000_000, samples: 80)
        let system = try frame(channel: .system, timestamp: 1_000_000_000, samples: 80)

        await buffer.append(first)
        await buffer.append(second)
        await buffer.append(system)

        #expect(await buffer.frames(after: first.endTimestampNanoseconds, channel: .microphone) == [second])
        #expect(await buffer.frames(after: 0, channel: .system) == [system])
    }

    @Test func evictsOldFramesAndReportsDrops() async throws {
        let buffer = RollingAudioBuffer(windowNanoseconds: 1_000_000, maximumFrameCount: 2)
        for timestamp in [0, 100_000, 200_000] {
            try await buffer.append(frame(channel: .microphone, timestamp: UInt64(timestamp), samples: 1))
        }

        let metrics = await buffer.metrics()
        #expect(metrics.retainedFrameCount == 2)
        #expect(metrics.droppedFrameCount == 1)
        #expect(await (buffer.frames(after: 0, channel: .microphone)).count == 2)
    }

    @Test func rejectsRegressedAndOverlappingFramesWithoutCorruptingReplay() async throws {
        let buffer = RollingAudioBuffer()
        let first = try frame(channel: .microphone, timestamp: 1000, samples: 8)
        let overlapping = try frame(channel: .microphone, timestamp: 1100, samples: 8)
        let regressed = try frame(channel: .microphone, timestamp: 900, samples: 8)

        await buffer.append(first)
        await buffer.append(overlapping)
        await buffer.append(regressed)

        #expect(await buffer.frames(after: 0, channel: .microphone) == [first])
        #expect(await (buffer.metrics()).discontinuityCount == 2)
    }

    private func frame(channel: AudioChannel, timestamp: UInt64, samples: Int) throws -> AudioFrame {
        try AudioFrame(
            channel: channel,
            timestampNanoseconds: timestamp,
            pcm16: Data(count: samples * AudioFrame.bytesPerSample)
        )
    }
}
