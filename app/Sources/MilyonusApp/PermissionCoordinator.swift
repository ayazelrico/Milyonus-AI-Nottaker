import Observation
import Permissions
import Shared

@MainActor
@Observable
final class PermissionCoordinator {
    private let service: any PermissionService
    private(set) var snapshot = PermissionSnapshot(
        microphone: .notDetermined,
        systemAudio: .notDetermined,
        notifications: .notDetermined
    )
    private(set) var pendingPermission: AppPermission?
    private(set) var errorKey: String?

    init(service: any PermissionService = MacOSPermissionManager()) {
        self.service = service
    }

    func refresh() async {
        snapshot = await service.snapshot()
    }

    func request(_ permission: AppPermission) async {
        guard pendingPermission == nil else { return }
        pendingPermission = permission
        errorKey = nil
        _ = await service.request(permission)
        snapshot = await service.snapshot()
        pendingPermission = nil
    }

    func openSystemSettings(for permission: AppPermission) async {
        errorKey = nil
        do {
            try await service.openSystemSettings(for: permission)
        } catch {
            errorKey = "System Settings could not be opened."
        }
    }

    func restartApplication() async {
        errorKey = nil
        do {
            try await service.restartApplication()
        } catch {
            errorKey = "Milyonus could not restart automatically. Quit and reopen the app."
        }
    }
}
