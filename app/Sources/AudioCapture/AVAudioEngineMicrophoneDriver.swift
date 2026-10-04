@preconcurrency import AudioToolbox
@preconcurrency import AVFoundation
import Foundation
import Shared

final class AVAudioEngineMicrophoneDriver: MicrophoneEngineDriving, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.milyonus.audio.microphone-engine")
    private var engine: AVAudioEngine?
    private var configurationObserver: NSObjectProtocol?

    func start(
        deviceID: String?,
        frameHandler: @escaping @Sendable (AudioFrame) -> Void,
        configurationHandler: @escaping @Sendable () -> Void
    ) throws {
        try queue.sync {
            stopLocked()

            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            if let deviceID {
                try apply(deviceID: deviceID, to: inputNode)
            }

            let inputFormat = inputNode.inputFormat(forBus: 0)
            guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
                throw MicrophoneCaptureError.unsupportedInputFormat
            }
            let converter = try MicrophoneFrameConverter(inputFormat: inputFormat)
            let requestedFrames = max(1, inputFormat.sampleRate * 0.1)
            let bufferSize = AVAudioFrameCount(min(4096, requestedFrames))

            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { buffer, time in
                let timestamp = time.hostTime == 0
                    ? DispatchTime.now().uptimeNanoseconds
                    : AudioConvertHostTimeToNanos(time.hostTime)
                do {
                    if let frame = try converter.convert(buffer, timestampNanoseconds: timestamp) {
                        frameHandler(frame)
                    }
                } catch {
                    // The owner receives engine-level failures. Individual malformed buffers are dropped.
                }
            }

            engine.prepare()
            do {
                try engine.start()
            } catch {
                inputNode.removeTap(onBus: 0)
                throw MicrophoneCaptureError.engineStartFailed
            }

            configurationObserver = NotificationCenter.default.addObserver(
                forName: .AVAudioEngineConfigurationChange,
                object: engine,
                queue: nil
            ) { _ in
                configurationHandler()
            }
            self.engine = engine
        }
    }

    func stop() {
        queue.sync { stopLocked() }
    }

    private func stopLocked() {
        if let observer = configurationObserver {
            NotificationCenter.default.removeObserver(observer)
            configurationObserver = nil
        }
        guard let engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        self.engine = nil
    }

    private func apply(deviceID: String, to inputNode: AVAudioInputNode) throws {
        guard let numericID = UInt32(deviceID) else {
            throw MicrophoneCaptureError.invalidDeviceID(deviceID)
        }
        guard let audioUnit = inputNode.audioUnit else {
            throw MicrophoneCaptureError.deviceUnavailable(deviceID)
        }
        var selectedID = AudioDeviceID(numericID)
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &selectedID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw MicrophoneCaptureError.deviceUnavailable(deviceID)
        }
    }
}
