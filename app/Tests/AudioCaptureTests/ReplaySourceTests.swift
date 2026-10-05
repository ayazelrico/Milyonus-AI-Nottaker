@testable import AudioCapture
import Foundation
import Shared
import Testing

struct ReplaySourceTests {
    @Test(arguments: ReplayFixtureLanguage.allCases, AudioChannel.allCases)
    func bundledFixturesEmitValidFrames(
        language: ReplayFixtureLanguage,
        channel: AudioChannel
    ) async throws {
        let fixture = ReplayFixture(language: language, channel: channel)
        let source = ReplaySource(
            fixture: fixture,
            pacing: .immediate,
            startTimestampNanoseconds: 1_000_000_000
        )

        #expect(await source.availability() == .ready)
        let frames = try await collect(source.start())

        #expect(!frames.isEmpty)
        #expect(frames.allSatisfy { $0.channel == channel })
        #expect(frames.first?.timestampNanoseconds == 1_000_000_000)
        #expect(frames.dropFirst().enumerated().allSatisfy { index, frame in
            frame.timestampNanoseconds == frames[index].endTimestampNanoseconds
        })
        #expect(frames.dropLast().allSatisfy { $0.sampleCount == 320 })
        #expect(await source.captureMetrics().deliveredFrameCount == UInt64(frames.count))
        #expect(await source.captureMetrics().droppedFrameCount == 0)
    }

    @Test func rejectsSecondActiveReplay() async throws {
        let fixture = ReplayFixture(language: .english, channel: .microphone)
        let source = ReplaySource(fixture: fixture, pacing: .realTime)
        let stream = try await source.start()

        do {
            _ = try await source.start()
            Issue.record("Expected already-running error")
        } catch {
            #expect(error as? ReplaySourceError == .alreadyRunning)
        }
        _ = stream
        await source.stop()
    }

    @Test(.timeLimit(.minutes(1)))
    func realTimeReplayUsesFixtureDurationAndFinishes() async throws {
        let fixture = ReplayFixture(language: .english, channel: .system)
        let source = ReplaySource(fixture: fixture, pacing: .realTime)
        let clock = ContinuousClock()
        let start = clock.now

        let frames = try await collect(source.start())
        let elapsed = start.duration(to: clock.now)

        #expect(!frames.isEmpty)
        #expect(elapsed > .seconds(4))
        #expect(elapsed < .seconds(5))
    }

    @Test func unavailableFixtureFailsBeforeStarting() async {
        let fixture = ReplayFixture(language: .english, channel: .system)
        let source = ReplaySource(fixture: fixture, pacing: .immediate) { _ in
            throw ReplaySourceError.missingFixture("test")
        }

        #expect(await source.availability() == .unavailable(.providerFailure))
        do {
            _ = try await source.start()
            Issue.record("Expected missing fixture error")
        } catch {
            #expect(error as? ReplaySourceError == .missingFixture("test"))
        }
    }

    @Test func invalidWaveDataIsRejected() async {
        let fixture = ReplayFixture(language: .turkish, channel: .microphone)
        let source = ReplaySource(fixture: fixture, pacing: .immediate) { _ in Data("invalid".utf8) }

        do {
            _ = try await source.start()
            Issue.record("Expected invalid WAVE error")
        } catch {
            #expect(error as? ReplaySourceError == .invalidWaveFile)
        }
    }

    private func collect(
        _ stream: AsyncThrowingStream<AudioFrame, Error>
    ) async throws -> [AudioFrame] {
        var frames: [AudioFrame] = []
        for try await frame in stream {
            frames.append(frame)
        }
        return frames
    }
}
