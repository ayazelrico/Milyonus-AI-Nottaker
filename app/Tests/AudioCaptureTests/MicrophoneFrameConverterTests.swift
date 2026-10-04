@testable import AudioCapture
import AVFoundation
import Shared
import Testing

struct MicrophoneFrameConverterTests {
    @Test func convertsStereoFloat48kToMonoPCM16At16k() throws {
        let inputFormat = try #require(
            AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 2, interleaved: false)
        )
        let input = try #require(AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 480))
        input.frameLength = 480
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
        #expect(abs(frame.sampleCount - 160) <= 2)
        let firstSample = frame.pcm16.withUnsafeBytes { $0.load(as: Int16.self) }
        #expect(abs(Int(firstSample) - 8192) <= 700)
    }
}
