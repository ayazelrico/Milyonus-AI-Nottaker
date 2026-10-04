import Foundation

public enum SystemAudioCaptureError: Error, Sendable, Equatable {
    case permissionDenied
    case alreadyRunning
    case noShareableDisplay
    case appIdentityUnavailable
    case outputRegistrationFailed
    case unsupportedAudioFormat
    case conversionFailed
    case captureStartFailed
    case streamStopped
}
