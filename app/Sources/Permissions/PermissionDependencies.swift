@preconcurrency import AppKit
@preconcurrency import AVFoundation
@preconcurrency import CoreGraphics
import Foundation
import Shared
@preconcurrency import UserNotifications

protocol MicrophonePermissionClient: Sendable {
    func status() -> AppPermissionStatus
    func request() async -> Bool
}

struct SystemMicrophonePermissionClient: MicrophonePermissionClient {
    func status() -> AppPermissionStatus {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined: .notDetermined
        case .denied: .denied
        case .granted: .granted
        @unknown default: .denied
        }
    }

    func request() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

protocol ScreenCapturePermissionClient: Sendable {
    func hasAccess() -> Bool
    func request() -> Bool
}

struct SystemScreenCapturePermissionClient: ScreenCapturePermissionClient {
    func hasAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    func request() -> Bool {
        CGRequestScreenCaptureAccess()
    }
}

protocol NotificationPermissionClient: Sendable {
    func status() async -> AppPermissionStatus
    func request() async -> Bool
}

struct SystemNotificationPermissionClient: NotificationPermissionClient {
    func status() async -> AppPermissionStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return switch settings.authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized, .provisional, .ephemeral: .granted
        @unknown default: .denied
        }
    }

    func request() async -> Bool {
        await (try? UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }
}

protocol PermissionRequestHistory: Sendable {
    var hasRequestedScreenCapture: Bool { get }
    func markScreenCaptureRequested()
}

final class UserDefaultsPermissionRequestHistory: PermissionRequestHistory, @unchecked Sendable {
    private static let screenCaptureKey = "permissions.screenCapture.requested"
    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasRequestedScreenCapture: Bool {
        lock.withLock { defaults.bool(forKey: Self.screenCaptureKey) }
    }

    func markScreenCaptureRequested() {
        lock.withLock { defaults.set(true, forKey: Self.screenCaptureKey) }
    }
}

protocol SystemSettingsOpening: Sendable {
    func open(_ url: URL) async -> Bool
}

struct WorkspaceSystemSettingsOpener: SystemSettingsOpening {
    @MainActor func open(_ url: URL) async -> Bool {
        NSWorkspace.shared.open(url)
    }
}

protocol ApplicationRestarting: Sendable {
    func restart() async -> Bool
}

struct WorkspaceApplicationRestarter: ApplicationRestarting {
    @MainActor func restart() async -> Bool {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        do {
            _ = try await NSWorkspace.shared.openApplication(
                at: Bundle.main.bundleURL,
                configuration: configuration
            )
            NSApplication.shared.terminate(nil)
            return true
        } catch {
            return false
        }
    }
}
