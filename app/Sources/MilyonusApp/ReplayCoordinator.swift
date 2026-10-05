#if DEBUG
    import AudioCapture
    import Foundation
    import Observation
    import Shared

    @MainActor
    @Observable
    final class ReplayCoordinator {
        enum State: Equatable {
            case idle
            case running
            case completed
            case failed
        }

        private(set) var state: State = .idle
        private var replayTask: Task<Void, Never>?

        var isRunning: Bool {
            state == .running
        }

        var statusKey: String {
            switch state {
            case .idle: "Replay ready"
            case .running: "Replay is running"
            case .completed: "Replay completed"
            case .failed: "Replay failed"
            }
        }

        func run(language: ReplayFixtureLanguage) {
            guard replayTask == nil else { return }
            state = .running
            replayTask = Task { [weak self] in
                await self?.performReplay(language: language)
            }
        }

        private func performReplay(language: ReplayFixtureLanguage) async {
            let baseTimestamp = DispatchTime.now().uptimeNanoseconds
            let microphone = ReplaySource(
                fixture: ReplayFixture(language: language, channel: .microphone),
                startTimestampNanoseconds: baseTimestamp
            )
            let system = ReplaySource(
                fixture: ReplayFixture(language: language, channel: .system),
                startTimestampNanoseconds: baseTimestamp
            )

            do {
                let microphoneStream = try await microphone.start()
                let systemStream = try await system.start()
                async let microphoneCount = Self.consume(microphoneStream)
                async let systemCount = Self.consume(systemStream)
                _ = try await (microphoneCount, systemCount)
                await microphone.stop()
                await system.stop()
                state = .completed
            } catch {
                await microphone.stop()
                await system.stop()
                state = .failed
            }
            replayTask = nil
        }

        private nonisolated static func consume(
            _ stream: AsyncThrowingStream<AudioFrame, Error>
        ) async throws -> Int {
            var frameCount = 0
            for try await _ in stream {
                frameCount += 1
            }
            return frameCount
        }
    }
#endif
