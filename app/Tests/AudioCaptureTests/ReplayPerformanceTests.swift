import AudioCapture
import Foundation
import Shared
import Testing

struct ReplayPerformanceTests {
    @Test("English and Turkish replay baseline")
    func replayBaselineHasNoCaptureDrops() async throws {
        for language in ReplayFixtureLanguage.allCases {
            let microphone = ReplaySource(
                fixture: ReplayFixture(language: language, channel: .microphone),
                pacing: .immediate
            )
            let system = ReplaySource(
                fixture: ReplayFixture(language: language, channel: .system),
                pacing: .immediate
            )
            let rollingBuffer = RollingAudioBuffer()
            let microphoneStream = try await microphone.start()
            let systemStream = try await system.start()

            async let microphoneFrames = consume(microphoneStream, buffer: rollingBuffer)
            async let systemFrames = consume(systemStream, buffer: rollingBuffer)
            let counts = try await (microphoneFrames, systemFrames)
            let metrics = await rollingBuffer.metrics()

            #expect(counts.0 > 0)
            #expect(counts.1 > 0)
            #expect(metrics.droppedFrameCount == 0)
            #expect(metrics.discontinuityCount == 0)
            await microphone.stop()
            await system.stop()
        }
    }

    private func consume(
        _ stream: AsyncThrowingStream<AudioFrame, Error>,
        buffer: RollingAudioBuffer
    ) async throws -> Int {
        var count = 0
        for try await frame in stream {
            await buffer.append(frame)
            count += 1
        }
        return count
    }
}
