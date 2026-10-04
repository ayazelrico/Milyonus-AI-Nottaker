import Foundation

public enum MicrophoneCaptureError: Error, Sendable, Equatable {
    case permissionUndetermined
    case permissionDenied
    case alreadyRunning
    case noInputDevice
    case invalidDeviceID(String)
    case deviceUnavailable(String)
    case unsupportedInputFormat
    case converterCreationFailed
    case conversionFailed
    case engineStartFailed
}
