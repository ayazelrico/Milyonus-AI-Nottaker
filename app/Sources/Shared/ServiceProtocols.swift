import Foundation

public protocol AudioSource: Sendable {
    var channel: AudioChannel { get }
    func availability() async -> ServiceAvailability
    func start() async throws -> AsyncThrowingStream<AudioFrame, Error>
    func stop() async
}

public protocol AudioInputDeviceService: Sendable {
    func inputDevices() async throws -> [AudioInputDevice]
    func selectedInputDeviceID() async -> String?
    /// Pass `nil` to follow the macOS system default input device.
    func selectInputDevice(id: String?) async throws
}

public protocol AudioCaptureMetricsService: Sendable {
    func captureMetrics() async -> AudioCaptureMetrics
}

public enum AppPermission: String, Sendable, CaseIterable, Codable {
    case microphone
    case systemAudio
    case notifications
}

public enum AppPermissionStatus: String, Sendable, Equatable, Codable {
    case notDetermined
    case granted
    case denied
    case restartRequired
}

public struct PermissionSnapshot: Sendable, Equatable {
    public let microphone: AppPermissionStatus
    public let systemAudio: AppPermissionStatus
    public let notifications: AppPermissionStatus

    public init(
        microphone: AppPermissionStatus,
        systemAudio: AppPermissionStatus,
        notifications: AppPermissionStatus
    ) {
        self.microphone = microphone
        self.systemAudio = systemAudio
        self.notifications = notifications
    }

    public subscript(permission: AppPermission) -> AppPermissionStatus {
        switch permission {
        case .microphone: microphone
        case .systemAudio: systemAudio
        case .notifications: notifications
        }
    }
}

public protocol PermissionService: Sendable {
    func snapshot() async -> PermissionSnapshot
    func request(_ permission: AppPermission) async -> AppPermissionStatus
    func openSystemSettings(for permission: AppPermission) async throws
    func restartApplication() async throws
}

public protocol TranscriptionService: Sendable {
    func availability() async -> ServiceAvailability
    func transcribe(
        meetingID: UUID,
        frames: AsyncThrowingStream<AudioFrame, Error>,
        language: AppLanguage
    ) async throws -> AsyncThrowingStream<TranscriptSegment, Error>
    func stop() async
}

public protocol LanguageModelService: Sendable {
    func availability() async -> ServiceAvailability
    func generate(_ request: GenerationRequest) async throws -> AsyncThrowingStream<GenerationEvent, Error>
}

public protocol EmbeddingService: Sendable {
    func availability() async -> ServiceAvailability
    func embed(_ texts: [String]) async throws -> [EmbeddingVector]
}

public protocol MeetingStorage: Sendable {
    func save(_ meeting: MeetingRecord) async throws
    func meetings() async throws -> [MeetingRecord]
    func append(_ segments: [TranscriptSegment], to meetingID: UUID) async throws
    func transcript(for meetingID: UUID) async throws -> [TranscriptSegment]
    func delete(meetingID: UUID) async throws
}

public protocol CalendarService: Sendable {
    func authorization() async -> CalendarAuthorization
    func requestAuthorization() async throws -> CalendarAuthorization
    func meetings(in interval: DateInterval) async throws -> [CalendarMeeting]
}

public protocol AuthenticationService: Sendable {
    func currentSession() async throws -> AuthSession?
    func requestMagicLink(email: String) async throws
    func completeSignIn(callbackURL: URL) async throws -> AuthSession
    func signIn(using provider: SignInProvider) async throws -> AuthSession
    func signOut() async throws
}

public protocol AccountIdentityService: Sendable {
    func identity(for session: AuthSession) async throws -> AccountIdentity
}

public protocol BillingService: Sendable {
    func availability() async -> ServiceAvailability
    func usageAllowance() async throws -> UsageAllowance
    func customerPortalURL() async throws -> URL
}
