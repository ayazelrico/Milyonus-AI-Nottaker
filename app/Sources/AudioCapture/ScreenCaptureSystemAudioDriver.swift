@preconcurrency import AVFoundation
@preconcurrency import CoreGraphics
@preconcurrency import CoreMedia
import Foundation
@preconcurrency import ScreenCaptureKit
import Shared

protocol ScreenCapturePermissionChecking: Sendable {
    func hasAccess() -> Bool
}

struct SystemScreenCapturePermissionChecker: ScreenCapturePermissionChecking {
    func hasAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }
}

protocol SystemAudioStreamDriving: Sendable {
    func start(
        frameHandler: @escaping @Sendable (AudioFrame) -> Void,
        failureHandler: @escaping @Sendable (SystemAudioCaptureError) -> Void
    ) async throws
    func stop() async
}

final class ScreenCaptureSystemAudioDriver: NSObject, SystemAudioStreamDriving, SCStreamDelegate, @unchecked Sendable {
    private let sampleQueue = DispatchQueue(label: "com.milyonus.audio.system-samples")
    private let lock = NSLock()
    private var stream: SCStream?
    private var output: SystemAudioStreamOutput?

    func start(
        frameHandler: @escaping @Sendable (AudioFrame) -> Void,
        failureHandler: @escaping @Sendable (SystemAudioCaptureError) -> Void
    ) async throws {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        } catch {
            throw SystemAudioCaptureError.permissionDenied
        }
        guard let display = content.displays.first else {
            throw SystemAudioCaptureError.noShareableDisplay
        }

        let currentProcessID = ProcessInfo.processInfo.processIdentifier
        let bundleIdentifier = Bundle.main.bundleIdentifier
        let excludedApplications = content.applications.filter {
            $0.processID == currentProcessID || $0.bundleIdentifier == bundleIdentifier
        }
        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApplications,
            exceptingWindows: []
        )
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true
        configuration.sampleRate = 16000
        configuration.channelCount = 1
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(seconds: 1, preferredTimescale: 1)
        configuration.queueDepth = 3
        configuration.showsCursor = false

        let output = SystemAudioStreamOutput(frameHandler: frameHandler)
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        do {
            try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: sampleQueue)
        } catch {
            throw SystemAudioCaptureError.outputRegistrationFailed
        }

        lock.withLock {
            self.stream = stream
            self.output = output
            output.failureHandler = failureHandler
        }
        do {
            try await stream.startCapture()
        } catch {
            lock.withLock {
                self.stream = nil
                self.output = nil
            }
            throw SystemAudioCaptureError.captureStartFailed
        }
    }

    func stop() async {
        let activeStream = lock.withLock { () -> SCStream? in
            defer {
                stream = nil
                output = nil
            }
            return stream
        }
        try? await activeStream?.stopCapture()
    }

    func stream(_: SCStream, didStopWithError _: Error) {
        let handler = lock.withLock { output?.failureHandler }
        handler?(.streamStopped)
    }
}

private final class SystemAudioStreamOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    private let frameHandler: @Sendable (AudioFrame) -> Void
    var failureHandler: (@Sendable (SystemAudioCaptureError) -> Void)?
    private var converter: MicrophoneFrameConverter?
    private var inputFormat: AVAudioFormat?

    init(frameHandler: @escaping @Sendable (AudioFrame) -> Void) {
        self.frameHandler = frameHandler
    }

    func stream(_: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio, sampleBuffer.isValid, CMSampleBufferDataIsReady(sampleBuffer) else { return }
        do {
            let pcmBuffer = try makePCMBuffer(from: sampleBuffer)
            if inputFormat != pcmBuffer.format {
                inputFormat = pcmBuffer.format
                converter = try MicrophoneFrameConverter(inputFormat: pcmBuffer.format, channel: .system)
            }
            let timestamp = Self.timestampNanoseconds(for: sampleBuffer)
            if let frame = try converter?.convert(pcmBuffer, timestampNanoseconds: timestamp) {
                frameHandler(frame)
            }
        } catch {
            failureHandler?(.conversionFailed)
        }
    }

    private func makePCMBuffer(from sampleBuffer: CMSampleBuffer) throws -> AVAudioPCMBuffer {
        guard let description = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(description),
              let format = AVAudioFormat(streamDescription: streamDescription)
        else {
            throw SystemAudioCaptureError.unsupportedAudioFormat
        }

        let maximumBuffers = max(1, Int(streamDescription.pointee.mChannelsPerFrame))
        let bufferList = AudioBufferList.allocate(maximumBuffers: maximumBuffers)
        defer { bufferList.unsafeMutablePointer.deallocate() }
        var retainedBlockBuffer: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: bufferList.unsafeMutablePointer,
            bufferListSize: AudioBufferList.sizeInBytes(maximumBuffers: maximumBuffers),
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: UInt32(kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment),
            blockBufferOut: &retainedBlockBuffer
        )
        guard status == noErr else {
            throw SystemAudioCaptureError.unsupportedAudioFormat
        }
        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard let ownedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw SystemAudioCaptureError.unsupportedAudioFormat
        }
        ownedBuffer.frameLength = frameCount
        let destinationBuffers = UnsafeMutableAudioBufferListPointer(ownedBuffer.mutableAudioBufferList)
        guard destinationBuffers.count == bufferList.count else {
            throw SystemAudioCaptureError.unsupportedAudioFormat
        }
        for index in 0 ..< bufferList.count {
            let source = bufferList[index]
            var destination = destinationBuffers[index]
            guard let sourceData = source.mData, let destinationData = destination.mData else {
                throw SystemAudioCaptureError.unsupportedAudioFormat
            }
            let byteCount = min(source.mDataByteSize, destination.mDataByteSize)
            memcpy(destinationData, sourceData, Int(byteCount))
            destination.mDataByteSize = byteCount
            destinationBuffers[index] = destination
        }
        return ownedBuffer
    }

    private static func timestampNanoseconds(for sampleBuffer: CMSampleBuffer) -> UInt64 {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard timestamp.isValid, timestamp.value >= 0 else {
            return DispatchTime.now().uptimeNanoseconds
        }
        let nanoseconds = CMTimeConvertScale(timestamp, timescale: 1_000_000_000, method: .default)
        return UInt64(nanoseconds.value)
    }
}
