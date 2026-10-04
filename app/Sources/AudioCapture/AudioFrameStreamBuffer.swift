import Foundation
import Shared

final class AudioFrameStreamBuffer: @unchecked Sendable {
    let stream: AsyncThrowingStream<AudioFrame, Error>

    private let lock = NSLock()
    private let continuation: AsyncThrowingStream<AudioFrame, Error>.Continuation
    private var deliveredFrameCount: UInt64 = 0
    private var droppedFrameCount: UInt64 = 0
    private var restartCount: UInt64 = 0

    init(limit: Int = 32) {
        var storedContinuation: AsyncThrowingStream<AudioFrame, Error>.Continuation?
        stream = AsyncThrowingStream(bufferingPolicy: .bufferingNewest(limit)) { continuation in
            storedContinuation = continuation
        }
        continuation = storedContinuation!
    }

    func yield(_ frame: AudioFrame) {
        let result = continuation.yield(frame)
        lock.lock()
        switch result {
        case .enqueued:
            deliveredFrameCount += 1
        case .dropped:
            deliveredFrameCount += 1
            droppedFrameCount += 1
        case .terminated:
            break
        @unknown default:
            break
        }
        lock.unlock()
    }

    func recordRestart() {
        lock.withLock { restartCount += 1 }
    }

    func metrics() -> AudioCaptureMetrics {
        lock.withLock {
            AudioCaptureMetrics(
                deliveredFrameCount: deliveredFrameCount,
                droppedFrameCount: droppedFrameCount,
                restartCount: restartCount
            )
        }
    }

    func finish(throwing error: Error? = nil) {
        if let error {
            continuation.finish(throwing: error)
        } else {
            continuation.finish()
        }
    }

    func onTermination(_ handler: @escaping @Sendable () -> Void) {
        continuation.onTermination = { _ in handler() }
    }
}
