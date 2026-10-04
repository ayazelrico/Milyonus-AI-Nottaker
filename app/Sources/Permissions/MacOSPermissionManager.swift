import Foundation
import Shared

public actor MacOSPermissionManager: PermissionService {
    private let microphone: any MicrophonePermissionClient
    private let screenCapture: any ScreenCapturePermissionClient
    private let notifications: any NotificationPermissionClient
    private let history: any PermissionRequestHistory
    private let settingsOpener: any SystemSettingsOpening
    private let restarter: any ApplicationRestarting
    private var screenCaptureRestartRequired = false

    public init() {
        microphone = SystemMicrophonePermissionClient()
        screenCapture = SystemScreenCapturePermissionClient()
        notifications = SystemNotificationPermissionClient()
        history = UserDefaultsPermissionRequestHistory()
        settingsOpener = WorkspaceSystemSettingsOpener()
        restarter = WorkspaceApplicationRestarter()
    }

    init(
        microphone: any MicrophonePermissionClient,
        screenCapture: any ScreenCapturePermissionClient,
        notifications: any NotificationPermissionClient,
        history: any PermissionRequestHistory,
        settingsOpener: any SystemSettingsOpening,
        restarter: any ApplicationRestarting
    ) {
        self.microphone = microphone
        self.screenCapture = screenCapture
        self.notifications = notifications
        self.history = history
        self.settingsOpener = settingsOpener
        self.restarter = restarter
    }

    public func snapshot() async -> PermissionSnapshot {
        await PermissionSnapshot(
            microphone: microphone.status(),
            systemAudio: screenCaptureStatus(),
            notifications: notifications.status()
        )
    }

    public func request(_ permission: AppPermission) async -> AppPermissionStatus {
        switch permission {
        case .microphone:
            _ = await microphone.request()
            return microphone.status()
        case .systemAudio:
            history.markScreenCaptureRequested()
            let granted = screenCapture.request()
            if screenCapture.hasAccess() {
                screenCaptureRestartRequired = false
                return .granted
            }
            if granted {
                screenCaptureRestartRequired = true
                return .restartRequired
            }
            return .denied
        case .notifications:
            _ = await notifications.request()
            return await notifications.status()
        }
    }

    public func openSystemSettings(for permission: AppPermission) async throws {
        guard let url = Self.settingsURL(for: permission) else {
            throw PermissionManagerError.invalidSystemSettingsURL
        }
        guard await settingsOpener.open(url) else {
            throw PermissionManagerError.unableToOpenSystemSettings
        }
    }

    public func restartApplication() async throws {
        guard await restarter.restart() else {
            throw PermissionManagerError.unableToRestartApplication
        }
    }

    static func settingsURL(for permission: AppPermission) -> URL? {
        let value = switch permission {
        case .microphone:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .systemAudio:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        case .notifications:
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
        }
        return URL(string: value)
    }

    private func screenCaptureStatus() -> AppPermissionStatus {
        if screenCapture.hasAccess() {
            screenCaptureRestartRequired = false
            return .granted
        }
        if screenCaptureRestartRequired {
            return .restartRequired
        }
        return history.hasRequestedScreenCapture ? .denied : .notDetermined
    }
}
