@testable import AudioCapture
import AVFoundation
import Shared
import Testing

struct MicrophoneFrameConverterTests {
    @Test func convertsStereoFloat48kToMonoPCM16At16k() throws {
        let inputFormat = try #require(
            AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 2, interleaved: false)
        )
        let input = try #require(AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 4800))
        input.frameLength = 4800
        for channel in 0 ..< Int(inputFormat.channelCount) {
            let samples = try #require(input.floatChannelData?[channel])
            for index in 0 ..< Int(input.frameLength) {
                samples[index] = 0.25
            }
        }

        let converter = try MicrophoneFrameConverter(inputFormat: inputFormat)
        let converted = try converter.convert(input, timestampNanoseconds: 42)
        let frame = try #require(converted)

        #expect(frame.channel == .microphone)
        #expect(frame.timestampNanoseconds == 42)
        #expect(abs(frame.sampleCount - 1600) <= 16)
        let middleSample = frame.pcm16.withUnsafeBytes { bytes in
            bytes.loadUnaligned(fromByteOffset: frame.pcm16.count / 2, as: Int16.self)
        }
        #expect(abs(Int(middleSample) - 8192) <= 700)
    }
}
