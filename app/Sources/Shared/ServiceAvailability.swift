public enum ServiceUnavailableReason: String, Sendable, Equatable, Codable {
    case permissionDenied
    case signedOut
    case offline
    case subscriptionRequired
    case providerFailure
}

/// An adapter must establish readiness before reporting this service as available.
public enum ServiceAvailability: Sendable, Equatable {
    case unconfigured
    case ready
    case unavailable(ServiceUnavailableReason)

    public var isReady: Bool {
        self == .ready
    }
}

public enum DomainValidationError: Error, Sendable, Equatable {
    case emptyAudioFrame
    case incompletePCM16Sample
    case invalidTranscriptRange
    case invalidTranscriptRevision
    case emptyEmbedding
    case nonFiniteEmbedding
    case invalidCalendarRange
    case invalidUsage
    case emptySessionToken
}
