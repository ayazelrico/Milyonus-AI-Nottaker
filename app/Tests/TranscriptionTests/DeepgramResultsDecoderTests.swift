import Foundation
import Shared
import Testing
@testable import Transcription

@Suite("Deepgram results decoder")
struct DeepgramResultsDecoderTests {
    @Test func mapsInterimAndFinalResultsToOneStableSegmentIdentity() async throws {
        let meetingID = UUID()
        let mapper = DeepgramEventMapper(meetingID: meetingID, channel: .microphone)
        let interim = try #require(try DeepgramResultsDecoder.decode(
            resultJSON(text: " Hello ", start: 1.25, duration: 0.5, isFinal: false),
            offsetMilliseconds: 2000
        ))
        let final = try #require(try DeepgramResultsDecoder.decode(
            resultJSON(text: "Hello there", start: 1.25, duration: 0.75, isFinal: true),
            offsetMilliseconds: 2000
        ))

        let interimSegment = try #require(await mapper.map(interim))
        let finalSegment = try #require(await mapper.map(final))

        #expect(interimSegment.id == finalSegment.id)
        #expect(interimSegment.meetingID == meetingID)
        #expect(interimSegment.channel == .microphone)
        #expect(interimSegment.text == "Hello")
        #expect(interimSegment.startMilliseconds == 3250)
        #expect(finalSegment.endMilliseconds == 4000)
        #expect(finalSegment.isFinal)
        #expect(try await mapper.map(final) == nil)
    }

    @Test func ignoresNonResultAndEmptyTranscriptEvents() throws {
        let metadata = Data("{\"type\":\"Metadata\",\"request_id\":\"fixture\"}".utf8)
        #expect(try DeepgramResultsDecoder.decode(metadata, offsetMilliseconds: 0) == nil)
        #expect(try DeepgramResultsDecoder.decode(
            resultJSON(text: "  ", start: 0, duration: 0, isFinal: false),
            offsetMilliseconds: 0
        ) == nil)
    }

    @Test func rejectsMalformedAndUnsafeTiming() {
        #expect(throws: TranscriptionError.invalidProviderMessage) {
            try DeepgramResultsDecoder.decode(Data("not-json".utf8), offsetMilliseconds: 0)
        }
        #expect(throws: TranscriptionError.invalidProviderMessage) {
            try DeepgramResultsDecoder.decode(
                resultJSON(text: "hello", start: -1, duration: 1, isFinal: true),
                offsetMilliseconds: 0
            )
        }
    }

    private func resultJSON(text: String, start: Double, duration: Double, isFinal: Bool) throws -> Data {
        let object: [String: Any] = [
            "type": "Results",
            "start": start,
            "duration": duration,
            "is_final": isFinal,
            "channel": ["alternatives": [["transcript": text]]],
        ]
        return try JSONSerialization.data(withJSONObject: object)
    }
}
