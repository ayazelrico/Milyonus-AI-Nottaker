@preconcurrency import AVFoundation
import Foundation
import Shared

final class MicrophoneFrameConverter: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat
    private let channel: AudioChannel
    private let lock = NSLock()

    init(inputFormat: AVAudioFormat, channel: AudioChannel = .microphone) throws {
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0,
              let outputFormat = AVAudioFormat(
                  commonFormat: .pcmFormatInt16,
                  sampleRate: Double(AudioFrame.sampleRate),
                  channels: 1,
                  interleaved: false
              ),
              let converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        else {
            throw MicrophoneCaptureError.converterCreationFailed
        }
        self.outputFormat = outputFormat
        self.converter = converter
        self.channel = channel
    }

    func convert(_ input: AVAudioPCMBuffer, timestampNanoseconds: UInt64) throws -> AudioFrame? {
        lock.lock()
        defer { lock.unlock() }

        let ratio = outputFormat.sampleRate / input.format.sampleRate
        let capacity = max(1, AVAudioFrameCount(ceil(Double(input.frameLength) * ratio)) + 32)
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            throw MicrophoneCaptureError.conversionFailed
        }

        let feeder = ConverterInputFeeder(buffer: input)
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
            feeder.next(status: inputStatus)
        }

        guard conversionError == nil, status != .error else {
            throw MicrophoneCaptureError.conversionFailed
        }
        guard output.frameLength > 0 else { return nil }
        guard let samples = output.int16ChannelData?.pointee else {
            throw MicrophoneCaptureError.conversionFailed
        }

        let byteCount = Int(output.frameLength) * MemoryLayout<Int16>.size
        return try AudioFrame(
            channel: channel,
            timestampNanoseconds: timestampNanoseconds,
            pcm16: Data(bytes: samples, count: byteCount)
        )
    }
}

private final class ConverterInputFeeder: @unchecked Sendable {
    private let buffer: AVAudioPCMBuffer
    private let lock = NSLock()
    private var supplied = false

    init(buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func next(status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
        lock.withLock {
            guard !supplied else {
                status.pointee = .noDataNow
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
    }
}
