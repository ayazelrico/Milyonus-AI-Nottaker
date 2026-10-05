import Foundation
import Observation
import Shared

@MainActor
@Observable
final class LiveMeetingCoordinator {
    enum State: Equatable {
        case idle
        case starting
        case listening
        case stopping
        case failed
    }

    private let mixer: (any AudioMixerService)?
    private let transcription: (any TranscriptionService)?
    private var streamTask: Task<Void, Never>?

    var state = State.idle
    var consentConfirmed = false
    var segments: [TranscriptSegment] = []

    init(mixer: (any AudioMixerService)? = nil, transcription: (any TranscriptionService)? = nil) {
        self.mixer = mixer
        self.transcription = transcription
    }

    var isListening: Bool {
        state == .listening
    }

    var canStart: Bool {
        state == .idle && consentConfirmed && mixer != nil && transcription != nil
    }

    var unavailableReason: LiveMeetingUnavailableReason {
        if mixer == nil || transcription == nil {
            return .services
        }
        if !consentConfirmed {
            return .consent
        }
        return .none
    }

    func start(language: AppLanguage = .english) {
        guard canStart, let mixer, let transcription else {
            state = .failed
            return
        }

        state = .starting
        segments = []
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            do {
                let frames = try await mixer.start()
                let transcript = try await transcription.transcribe(
                    meetingID: UUID(),
                    frames: frames,
                    language: language
                )
                guard let self else { return }
                state = .listening
                for try await segment in transcript {
                    guard !Task.isCancelled else { return }
                    segments.append(segment)
                }
                if state == .listening {
                    state = .idle
                }
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                state = .failed
                await mixer.stop()
            }
        }
    }

    func stop() {
        guard state == .starting || state == .listening || state == .failed else { return }
        state = .stopping
        streamTask?.cancel()
        streamTask = nil
        Task { [weak self] in
            guard let self else { return }
            await transcription?.stop()
            await mixer?.stop()
            consentConfirmed = false
            state = .idle
        }
    }
}

enum LiveMeetingUnavailableReason: Equatable {
    case none
    case consent
    case services
}
