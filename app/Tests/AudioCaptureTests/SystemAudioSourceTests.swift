@testable import AudioCapture
import Foundation
import Shared
import Testing

struct SystemAudioSourceTests {
    @Test func deniesStartWithoutScreenCaptureAuthorization() async {
        let source = SystemAudioSource(
            driver: FakeSystemAudioDriver(),
            permissionChecker: FixedScreenPermission(hasAccess: false)
        )

        #expect(await source.availability() == .unavailable(.permissionDenied))
        do {
            _ = try await source.start()
            Issue.record("Expected permission error")
        } catch {
            #expect(error as? SystemAudioCaptureError == .permissionDenied)
        }
    }

    @Test func emitsSystemFramesFromDriver() async throws {
        let driver = FakeSystemAudioDriver()
        let source = makeSource(driver: driver)
        let stream = try await source.start()
        let frame = try AudioFrame(channel: .system, timestampNanoseconds: 72, pcm16: Data([1, 0]))

        driver.emit(frame)
        var iterator = stream.makeAsyncIterator()
        let received = try await iterator.next()

        #expect(received == frame)
        #expect(await source.captureMetrics().deliveredFrameCount == 1)
        await source.stop()
    }

    @Test func rejectsASecondActiveStream() async throws {
        let source = makeSource(driver: FakeSystemAudioDriver())
        let stream = try await source.start()

        do {
            _ = try await source.start()
            Issue.record("Expected already-running error")
        } catch {
            #expect(error as? SystemAudioCaptureError == .alreadyRunning)
        }
        _ = stream
        await source.stop()
    }

    @Test func unexpectedDriverStopFinishesWithTypedError() async throws {
        let driver = FakeSystemAudioDriver()
        let source = makeSource(driver: driver)
        let stream = try await source.start()
        var iterator = stream.makeAsyncIterator()

        driver.fail(.streamStopped)

        do {
            _ = try await iterator.next()
            Issue.record("Expected stream failure")
        } catch {
            #expect(error as? SystemAudioCaptureError == .streamStopped)
        }
    }

    @Test func stopClosesTheDriverOnce() async throws {
        let driver = FakeSystemAudioDriver()
        let source = makeSource(driver: driver)
        let stream = try await source.start()

        await source.stop()

        #expect(driver.stopCount == 1)
        _ = stream
    }

    private func makeSource(driver: FakeSystemAudioDriver) -> SystemAudioSource {
        SystemAudioSource(driver: driver, permissionChecker: FixedScreenPermission(hasAccess: true))
    }
}

private struct FixedScreenPermission: ScreenCapturePermissionChecking {
    let hasAccessValue: Bool

    init(hasAccess: Bool) {
        hasAccessValue = hasAccess
    }

    func hasAccess() -> Bool {
        hasAccessValue
    }
}

private final class FakeSystemAudioDriver: SystemAudioStreamDriving, @unchecked Sendable {
    private let lock = NSLock()
    private var frameHandler: (@Sendable (AudioFrame) -> Void)?
    private var failureHandler: (@Sendable (SystemAudioCaptureError) -> Void)?
    private var stops = 0

    var stopCount: Int {
        lock.withLock { stops }
    }

    func start(
        frameHandler: @escaping @Sendable (AudioFrame) -> Void,
        failureHandler: @escaping @Sendable (SystemAudioCaptureError) -> Void
    ) async throws {
        lock.withLock {
            self.frameHandler = frameHandler
            self.failureHandler = failureHandler
        }
    }

    func stop() async {
        lock.withLock { stops += 1 }
    }

    func emit(_ frame: AudioFrame) {
        let handler = lock.withLock { frameHandler }
        handler?(frame)
    }

    func fail(_ error: SystemAudioCaptureError) {
        let handler = lock.withLock { failureHandler }
        handler?(error)
    }
}
