@testable import AudioCapture
import Foundation
import Shared
import Testing

struct MicrophoneAudioSourceTests {
    @Test func availabilityReflectsPermissionWithoutRequestingIt() async {
        let undetermined = makeSource(permission: .undetermined)
        let denied = makeSource(permission: .denied)
        let authorized = makeSource(permission: .authorized)

        #expect(await undetermined.availability() == .unconfigured)
        #expect(await denied.availability() == .unavailable(.permissionDenied))
        #expect(await authorized.availability() == .ready)
    }

    @Test func startRejectsUndeterminedPermission() async {
        let source = makeSource(permission: .undetermined)
        do {
            _ = try await source.start()
            Issue.record("Expected permission error")
        } catch {
            #expect(error as? MicrophoneCaptureError == .permissionUndetermined)
        }
    }

    @Test func explicitDeviceSelectionIsAppliedOnStart() async throws {
        let driver = FakeEngineDriver()
        let source = makeSource(permission: .authorized, driver: driver)

        try await source.selectInputDevice(id: "7")
        let stream = try await source.start()

        #expect(driver.startedDeviceIDs == ["7"])
        _ = stream
        await source.stop()
    }

    @Test func configurationChangeRestartsAndTracksMetric() async throws {
        let driver = FakeEngineDriver()
        let source = makeSource(permission: .authorized, driver: driver)
        let stream = try await source.start()

        driver.sendConfigurationChange()
        try await Task.sleep(for: .milliseconds(50))

        #expect(driver.startCount == 2)
        #expect(await source.captureMetrics().restartCount == 1)
        _ = stream
        await source.stop()
    }

    @Test func boundedBufferReportsDroppedFrames() throws {
        let buffer = AudioFrameStreamBuffer(limit: 2)
        try buffer.yield(frame(timestamp: 1))
        try buffer.yield(frame(timestamp: 2))
        try buffer.yield(frame(timestamp: 3))

        #expect(buffer.metrics().deliveredFrameCount == 3)
        #expect(buffer.metrics().droppedFrameCount == 1)
        buffer.finish()
    }

    private func makeSource(
        permission: MicrophonePermission,
        driver: FakeEngineDriver = FakeEngineDriver()
    ) -> MicrophoneAudioSource {
        MicrophoneAudioSource(
            permissionProvider: FixedPermissionProvider(permission: permission),
            deviceCatalog: FixedDeviceCatalog(values: [
                AudioInputDevice(id: "7", name: "Test microphone", isDefault: true),
            ]),
            driver: driver
        )
    }

    private func frame(timestamp: UInt64) throws -> AudioFrame {
        try AudioFrame(channel: .microphone, timestampNanoseconds: timestamp, pcm16: Data([0, 0]))
    }
}

private struct FixedPermissionProvider: MicrophonePermissionProviding {
    let permission: MicrophonePermission

    func currentPermission() -> MicrophonePermission {
        permission
    }
}

private struct FixedDeviceCatalog: AudioInputDeviceCatalog {
    let values: [AudioInputDevice]

    func devices() throws -> [AudioInputDevice] {
        values
    }
}

private final class FakeEngineDriver: MicrophoneEngineDriving, @unchecked Sendable {
    private let lock = NSLock()
    private var configurationHandler: (@Sendable () -> Void)?
    private var deviceIDs: [String?] = []

    var startCount: Int {
        lock.withLock { deviceIDs.count }
    }

    var startedDeviceIDs: [String?] {
        lock.withLock { deviceIDs }
    }

    func start(
        deviceID: String?,
        frameHandler _: @escaping @Sendable (AudioFrame) -> Void,
        configurationHandler: @escaping @Sendable () -> Void
    ) throws {
        lock.withLock {
            deviceIDs.append(deviceID)
            self.configurationHandler = configurationHandler
        }
    }

    func stop() {}

    func sendConfigurationChange() {
        let handler = lock.withLock { configurationHandler }
        handler?()
    }
}
