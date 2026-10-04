import Foundation
import Shared

public actor SystemAudioSource: AudioSource, AudioCaptureMetricsService {
    public nonisolated let channel: AudioChannel = .system

    private let driver: any SystemAudioStreamDriving
    private let permissionChecker: any ScreenCapturePermissionChecking
    private var activeSessionID: UUID?
    private var activeBuffer: AudioFrameStreamBuffer?
    private var lastMetrics: AudioCaptureMetrics = .zero

    public init() {
        driver = ScreenCaptureSystemAudioDriver()
        permissionChecker = SystemScreenCapturePermissionChecker()
    }

    init(
        driver: any SystemAudioStreamDriving,
        permissionChecker: any ScreenCapturePermissionChecking
    ) {
        self.driver = driver
        self.permissionChecker = permissionChecker
    }

    public func availability() async -> ServiceAvailability {
        permissionChecker.hasAccess() ? .ready : .unavailable(.permissionDenied)
    }

    public func start() async throws -> AsyncThrowingStream<AudioFrame, Error> {
        guard activeSessionID == nil else { throw SystemAudioCaptureError.alreadyRunning }
        guard permissionChecker.hasAccess() else {
            throw SystemAudioCaptureError.permissionDenied
        }

        let sessionID = UUID()
        let buffer = AudioFrameStreamBuffer()
        activeSessionID = sessionID
        activeBuffer = buffer
        buffer.onTermination { [weak self] in
            Task { await self?.stop(sessionID: sessionID) }
        }
        do {
            try await driver.start(
                frameHandler: { buffer.yield($0) },
                failureHandler: { [weak self] error in
                    Task { await self?.finish(sessionID: sessionID, error: error) }
                }
            )
        } catch {
            finish(sessionID: sessionID, error: error)
            throw error
        }
        return buffer.stream
    }

    public func stop() async {
        await stop(sessionID: activeSessionID)
    }

    public func captureMetrics() async -> AudioCaptureMetrics {
        activeBuffer?.metrics() ?? lastMetrics
    }

    private func stop(sessionID: UUID?) async {
        guard let sessionID, activeSessionID == sessionID else { return }
        await driver.stop()
        finish(sessionID: sessionID, error: nil)
    }

    private func finish(sessionID: UUID, error: Error?) {
        guard activeSessionID == sessionID, let buffer = activeBuffer else { return }
        lastMetrics = buffer.metrics()
        activeSessionID = nil
        activeBuffer = nil
        buffer.finish(throwing: error)
    }
}
