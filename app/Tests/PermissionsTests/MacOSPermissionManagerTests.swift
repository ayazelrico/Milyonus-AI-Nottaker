import Foundation
@testable import Permissions
import Shared
import Testing

struct MacOSPermissionManagerTests {
    @Test func passiveSnapshotNeverRequestsPermission() async {
        let microphone = FakeMicrophone(status: .notDetermined)
        let screen = FakeScreenCapture(hasAccess: false, requestResult: false)
        let notifications = FakeNotifications(status: .notDetermined)
        let manager = makeManager(microphone: microphone, screen: screen, notifications: notifications)

        let snapshot = await manager.snapshot()

        #expect(snapshot.microphone == .notDetermined)
        #expect(snapshot.systemAudio == .notDetermined)
        #expect(snapshot.notifications == .notDetermined)
        #expect(microphone.requestCount == 0)
        #expect(screen.requestCount == 0)
        #expect(notifications.requestCount == 0)
    }

    @Test func priorScreenRequestMapsMissingAccessToDenied() async {
        let history = FakeHistory(hasRequested: true)
        let manager = makeManager(history: history)

        #expect(await manager.snapshot().systemAudio == .denied)
    }

    @Test func staleScreenGrantRequiresRestart() async {
        let screen = FakeScreenCapture(hasAccess: false, requestResult: true)
        let history = FakeHistory()
        let restarter = FakeRestarter(result: true)
        let manager = makeManager(screen: screen, history: history, restarter: restarter)

        #expect(await manager.request(.systemAudio) == .restartRequired)
        #expect(history.hasRequestedScreenCapture)
        #expect(await manager.snapshot().systemAudio == .restartRequired)
        try await manager.restartApplication()
        #expect(restarter.restartCount == 1)
    }

    @Test func screenGrantIsReadyWhenPreflightUpdatesImmediately() async {
        let screen = FakeScreenCapture(hasAccess: false, requestResult: true, grantOnRequest: true)
        let manager = makeManager(screen: screen)

        #expect(await manager.request(.systemAudio) == .granted)
    }

    @Test func opensThePermissionSpecificSettingsPane() async throws {
        let opener = FakeSettingsOpener(result: true)
        let manager = makeManager(settingsOpener: opener)

        try await manager.openSystemSettings(for: .microphone)

        #expect(opener.openedURLs.first?.absoluteString.contains("Privacy_Microphone") == true)
    }

    private func makeManager(
        microphone: FakeMicrophone = FakeMicrophone(status: .denied),
        screen: FakeScreenCapture = FakeScreenCapture(hasAccess: false, requestResult: false),
        notifications: FakeNotifications = FakeNotifications(status: .denied),
        history: FakeHistory = FakeHistory(),
        settingsOpener: FakeSettingsOpener = FakeSettingsOpener(result: true),
        restarter: FakeRestarter = FakeRestarter(result: true)
    ) -> MacOSPermissionManager {
        MacOSPermissionManager(
            microphone: microphone,
            screenCapture: screen,
            notifications: notifications,
            history: history,
            settingsOpener: settingsOpener,
            restarter: restarter
        )
    }
}

private final class FakeMicrophone: MicrophonePermissionClient, @unchecked Sendable {
    private let lock = NSLock()
    private var currentStatus: AppPermissionStatus
    private(set) var requestCount = 0

    init(status: AppPermissionStatus) {
        currentStatus = status
    }

    func status() -> AppPermissionStatus {
        lock.withLock { currentStatus }
    }

    func request() async -> Bool {
        lock.withLock { requestCount += 1 }
        return currentStatus == .granted
    }
}

private final class FakeScreenCapture: ScreenCapturePermissionClient, @unchecked Sendable {
    private let lock = NSLock()
    private var access: Bool
    private let requestResult: Bool
    private let grantOnRequest: Bool
    private(set) var requestCount = 0

    init(hasAccess: Bool, requestResult: Bool, grantOnRequest: Bool = false) {
        access = hasAccess
        self.requestResult = requestResult
        self.grantOnRequest = grantOnRequest
    }

    func hasAccess() -> Bool {
        lock.withLock { access }
    }

    func request() -> Bool {
        lock.withLock {
            requestCount += 1
            if grantOnRequest {
                access = true
            }
            return requestResult
        }
    }
}

private final class FakeNotifications: NotificationPermissionClient, @unchecked Sendable {
    private let lock = NSLock()
    private var currentStatus: AppPermissionStatus
    private(set) var requestCount = 0

    init(status: AppPermissionStatus) {
        currentStatus = status
    }

    func status() async -> AppPermissionStatus {
        lock.withLock { currentStatus }
    }

    func request() async -> Bool {
        lock.withLock { requestCount += 1 }
        return currentStatus == .granted
    }
}

private final class FakeHistory: PermissionRequestHistory, @unchecked Sendable {
    private let lock = NSLock()
    private var requested: Bool

    init(hasRequested: Bool = false) {
        requested = hasRequested
    }

    var hasRequestedScreenCapture: Bool {
        lock.withLock { requested }
    }

    func markScreenCaptureRequested() {
        lock.withLock { requested = true }
    }
}

private final class FakeSettingsOpener: SystemSettingsOpening, @unchecked Sendable {
    private let lock = NSLock()
    private let result: Bool
    private(set) var openedURLs: [URL] = []

    init(result: Bool) {
        self.result = result
    }

    func open(_ url: URL) async -> Bool {
        lock.withLock { openedURLs.append(url) }
        return result
    }
}

private final class FakeRestarter: ApplicationRestarting, @unchecked Sendable {
    private let lock = NSLock()
    private let result: Bool
    private(set) var restartCount = 0

    init(result: Bool) {
        self.result = result
    }

    func restart() async -> Bool {
        lock.withLock { restartCount += 1 }
        return result
    }
}
