import Foundation
import Shared

public actor MicrophoneAudioSource: AudioSource, AudioInputDeviceService, AudioCaptureMetricsService {
    public nonisolated let channel: AudioChannel = .microphone

    private let permissionProvider: any MicrophonePermissionProviding
    private let deviceCatalog: any AudioInputDeviceCatalog
    private let driver: any MicrophoneEngineDriving
    private var selectedDeviceID: String?
    private var activeSessionID: UUID?
    private var activeBuffer: AudioFrameStreamBuffer?
    private var lastMetrics: AudioCaptureMetrics = .zero

    public init() {
        permissionProvider = SystemMicrophonePermissionProvider()
        deviceCatalog = CoreAudioInputDeviceCatalog()
        driver = AVAudioEngineMicrophoneDriver()
    }

    init(
        permissionProvider: any MicrophonePermissionProviding,
        deviceCatalog: any AudioInputDeviceCatalog,
        driver: any MicrophoneEngineDriving
    ) {
        self.permissionProvider = permissionProvider
        self.deviceCatalog = deviceCatalog
        self.driver = driver
    }

    public func availability() async -> ServiceAvailability {
        switch permissionProvider.currentPermission() {
        case .undetermined:
            .unconfigured
        case .denied:
            .unavailable(.permissionDenied)
        case .authorized:
            (try? deviceCatalog.devices().isEmpty) == false ? .ready : .unavailable(.providerFailure)
        }
    }

    public func start() async throws -> AsyncThrowingStream<AudioFrame, Error> {
        guard activeSessionID == nil else { throw MicrophoneCaptureError.alreadyRunning }
        switch permissionProvider.currentPermission() {
        case .undetermined:
            throw MicrophoneCaptureError.permissionUndetermined
        case .denied:
            throw MicrophoneCaptureError.permissionDenied
        case .authorized:
            break
        }

        try validateSelectedDevice()
        let sessionID = UUID()
        let buffer = AudioFrameStreamBuffer()
        activeSessionID = sessionID
        activeBuffer = buffer
        buffer.onTermination { [weak self] in
            Task { await self?.stop(sessionID: sessionID) }
        }

        do {
            try driver.start(
                deviceID: selectedDeviceID,
                frameHandler: { buffer.yield($0) },
                configurationHandler: { [weak self] in
                    Task { await self?.recoverFromConfigurationChange(sessionID: sessionID) }
                }
            )
        } catch {
            activeSessionID = nil
            activeBuffer = nil
            buffer.finish(throwing: error)
            throw error
        }
        return buffer.stream
    }

    public func stop() async {
        stop(sessionID: activeSessionID)
    }

    public func inputDevices() async throws -> [AudioInputDevice] {
        try deviceCatalog.devices()
    }

    public func selectedInputDeviceID() async -> String? {
        selectedDeviceID
    }

    public func selectInputDevice(id: String?) async throws {
        if let id {
            guard try deviceCatalog.devices().contains(where: { $0.id == id }) else {
                throw MicrophoneCaptureError.deviceUnavailable(id)
            }
        }
        selectedDeviceID = id
        guard let sessionID = activeSessionID else { return }
        await recoverFromConfigurationChange(sessionID: sessionID)
    }

    public func captureMetrics() async -> AudioCaptureMetrics {
        activeBuffer?.metrics() ?? lastMetrics
    }

    private func validateSelectedDevice() throws {
        let devices = try deviceCatalog.devices()
        guard !devices.isEmpty else { throw MicrophoneCaptureError.noInputDevice }
        if let selectedDeviceID,
           !devices.contains(where: { $0.id == selectedDeviceID })
        {
            throw MicrophoneCaptureError.deviceUnavailable(selectedDeviceID)
        }
    }

    private func recoverFromConfigurationChange(sessionID: UUID) async {
        guard activeSessionID == sessionID, let buffer = activeBuffer else { return }
        driver.stop()
        do {
            try validateSelectedDevice()
            try driver.start(
                deviceID: selectedDeviceID,
                frameHandler: { buffer.yield($0) },
                configurationHandler: { [weak self] in
                    Task { await self?.recoverFromConfigurationChange(sessionID: sessionID) }
                }
            )
            buffer.recordRestart()
        } catch {
            finish(sessionID: sessionID, error: error)
        }
    }

    private func stop(sessionID: UUID?) {
        guard let sessionID, activeSessionID == sessionID else { return }
        driver.stop()
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
