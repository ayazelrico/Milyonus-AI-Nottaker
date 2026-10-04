import Foundation

public enum PermissionManagerError: Error, Sendable, Equatable {
    case invalidSystemSettingsURL
    case unableToOpenSystemSettings
    case unableToRestartApplication
}
