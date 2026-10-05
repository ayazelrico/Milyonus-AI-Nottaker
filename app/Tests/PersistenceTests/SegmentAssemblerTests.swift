import Foundation
import Persistence
import Shared
import Testing

@Suite("Segment assembler")
struct SegmentAssemblerTests {
    @Test("Emits only meaningful monotonic revisions")
    func revisions() async throws {
        let assembler = SegmentAssembler()
        let id = UUID()
        let meetingID = UUID()
        let interim = try segment(id: id, meetingID: meetingID, text: "hello", isFinal: false)
        let first = try #require(try await assembler.ingest(interim))
        #expect(first.revision == 1)
        #expect(try await assembler.ingest(interim) == nil)

        let final = try segment(id: id, meetingID: meetingID, text: "hello there", isFinal: true)
        let second = try #require(try await assembler.ingest(final))
        #expect(second.revision == 2)
        #expect(second.segment.isFinal)
    }

    @Test("Rejects identity changes and finality regression")
    func invalidTransitions() async throws {
        let assembler = SegmentAssembler()
        let id = UUID()
        let meetingID = UUID()
        let final = try segment(id: id, meetingID: meetingID, text: "final", isFinal: true)
        _ = try await assembler.ingest(final)

        await #expect(throws: TranscriptPersistenceError.finalityRegression) {
            _ = try await assembler.ingest(
                segment(id: id, meetingID: meetingID, text: "interim", isFinal: false)
            )
        }
        await #expect(throws: TranscriptPersistenceError.segmentIdentityChanged) {
            _ = try await assembler.ingest(
                segment(id: id, meetingID: UUID(), text: "different meeting", isFinal: true)
            )
        }
    }

    private func segment(
        id: UUID,
        meetingID: UUID,
        text: String,
        isFinal: Bool
    ) throws -> TranscriptSegment {
        try TranscriptSegment(
            id: id,
            meetingID: meetingID,
            channel: .microphone,
            text: text,
            startMilliseconds: 10,
            endMilliseconds: 20,
            isFinal: isFinal
        )
    }
}
