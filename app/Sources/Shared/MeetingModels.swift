import Foundation

public enum MeetingState: String, Sendable, Equatable, Codable {
    case idle
    case recording
    case paused
    case completed
}

public enum MeetingTransitionError: Error, Sendable, Equatable {
    case consentRequired
    case serviceUnavailable
    case invalidTransition
}

/// Pure state transitions only. Actual capture starts after permissions and service checks succeed.
public struct MeetingLifecycle: Sendable, Equatable {
    public private(set) var state: MeetingState = .idle

    public init() {}

    public mutating func begin(
        consentConfirmed: Bool,
        audio: ServiceAvailability,
        transcription: ServiceAvailability
    ) throws {
        guard state == .idle else { throw MeetingTransitionError.invalidTransition }
        try validateReadiness(consentConfirmed: consentConfirmed, audio: audio, transcription: transcription)
        state = .recording
    }

    public mutating func pause() throws {
        guard state == .recording else { throw MeetingTransitionError.invalidTransition }
        state = .paused
    }

    public mutating func resume(
        consentConfirmed: Bool,
        audio: ServiceAvailability,
        transcription: ServiceAvailability
    ) throws {
        guard state == .paused else { throw MeetingTransitionError.invalidTransition }
        try validateReadiness(consentConfirmed: consentConfirmed, audio: audio, transcription: transcription)
        state = .recording
    }

    public mutating func finish() throws {
        guard state == .recording || state == .paused else { throw MeetingTransitionError.invalidTransition }
        state = .completed
    }

    private func validateReadiness(
        consentConfirmed: Bool,
        audio: ServiceAvailability,
        transcription: ServiceAvailability
    ) throws {
        guard consentConfirmed else { throw MeetingTransitionError.consentRequired }
        guard audio.isReady, transcription.isReady else { throw MeetingTransitionError.serviceUnavailable }
    }
}

public struct MeetingRecord: Sendable, Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public let createdAt: Date
    public var language: AppLanguage

    public init(id: UUID = UUID(), title: String, createdAt: Date = Date(), language: AppLanguage = .defaultLanguage) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.language = language
    }
}
