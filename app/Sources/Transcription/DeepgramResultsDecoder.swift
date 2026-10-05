import Foundation
import Shared

struct DeepgramTranscriptResult: Sendable, Equatable {
    let text: String
    let startMilliseconds: Int
    let endMilliseconds: Int
    let isFinal: Bool
}

enum DeepgramResultsDecoder {
    static func decode(_ data: Data, offsetMilliseconds: Int) throws -> DeepgramTranscriptResult? {
        guard data.count <= 1_048_576 else { throw TranscriptionError.invalidProviderMessage }
        guard offsetMilliseconds >= 0 else { throw TranscriptionError.invalidProviderMessage }
        let event: DeepgramResultEvent
        do {
            event = try JSONDecoder().decode(DeepgramResultEvent.self, from: data)
        } catch {
            throw TranscriptionError.invalidProviderMessage
        }
        guard event.type == "Results" else { return nil }
        guard let start = event.start,
              let duration = event.duration,
              let isFinal = event.isFinal,
              let transcript = event.channel?.alternatives.first?.transcript
        else {
            throw TranscriptionError.invalidProviderMessage
        }

        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        guard start.isFinite,
              duration.isFinite,
              start >= 0,
              duration >= 0,
              start <= Double(Int.max - offsetMilliseconds) / 1000,
              duration <= Double(Int.max) / 1000
        else {
            throw TranscriptionError.invalidProviderMessage
        }

        let relativeStart = Int((start * 1000).rounded())
        let relativeDuration = Int((duration * 1000).rounded())
        let (startMilliseconds, startOverflow) = offsetMilliseconds.addingReportingOverflow(relativeStart)
        let (endMilliseconds, endOverflow) = startMilliseconds.addingReportingOverflow(relativeDuration)
        guard !startOverflow, !endOverflow else { throw TranscriptionError.invalidProviderMessage }

        return DeepgramTranscriptResult(
            text: text,
            startMilliseconds: startMilliseconds,
            endMilliseconds: endMilliseconds,
            isFinal: isFinal
        )
    }
}

private struct DeepgramResultAlternative: Decodable {
    let transcript: String
}

private struct DeepgramResultChannel: Decodable {
    let alternatives: [DeepgramResultAlternative]
}

private struct DeepgramResultEvent: Decodable {
    let type: String
    let start: Double?
    let duration: Double?
    let isFinal: Bool?
    let channel: DeepgramResultChannel?

    enum CodingKeys: String, CodingKey {
        case type
        case start
        case duration
        case isFinal = "is_final"
        case channel
    }
}

actor DeepgramEventMapper {
    private struct Signature: Hashable {
        let text: String
        let startMilliseconds: Int
        let endMilliseconds: Int
        let isFinal: Bool
    }

    private let meetingID: UUID
    private let channel: AudioChannel
    private var identifiers: [Int: UUID] = [:]
    private var delivered: Set<Signature> = []

    init(meetingID: UUID, channel: AudioChannel) {
        self.meetingID = meetingID
        self.channel = channel
    }

    func map(_ result: DeepgramTranscriptResult) throws -> TranscriptSegment? {
        let signature = Signature(
            text: result.text,
            startMilliseconds: result.startMilliseconds,
            endMilliseconds: result.endMilliseconds,
            isFinal: result.isFinal
        )
        guard delivered.insert(signature).inserted else { return nil }
        let identifier = identifiers[result.startMilliseconds] ?? UUID()
        identifiers[result.startMilliseconds] = identifier
        return try TranscriptSegment(
            id: identifier,
            meetingID: meetingID,
            channel: channel,
            text: result.text,
            startMilliseconds: result.startMilliseconds,
            endMilliseconds: result.endMilliseconds,
            isFinal: result.isFinal
        )
    }
}
