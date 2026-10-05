import Foundation
import Persistence
import Shared
import Testing

@Suite("Transcript outbox synchronizer")
struct TranscriptOutboxSynchronizerTests {
    @Test("Acknowledges the outbox only after a complete upload")
    func flush() async throws {
        let meetingID = UUID()
        let revision = try TranscriptSegmentRevision(
            segment: TranscriptSegment(
                meetingID: meetingID,
                channel: .system,
                text: "fixture",
                startMilliseconds: 0,
                endMilliseconds: 1,
                isFinal: true
            ),
            revision: 1
        )
        let storage = FixtureStorage(pending: [revision])
        let uploader = FixtureUploader(accepted: 1)
        let synchronizer = TranscriptOutboxSynchronizer(storage: storage, uploader: uploader)

        #expect(try await synchronizer.flush(
            workspaceID: UUID(),
            meetingID: meetingID
        ) == 1)
        #expect(try await storage.acknowledged == [
            TranscriptRevisionReference(segmentID: revision.id, revision: 1),
        ])
    }

    @Test("Does not acknowledge a partial response")
    func partialResponse() async throws {
        let meetingID = UUID()
        let revision = try TranscriptSegmentRevision(
            segment: TranscriptSegment(
                meetingID: meetingID,
                channel: .microphone,
                text: "fixture",
                startMilliseconds: 0,
                endMilliseconds: 1,
                isFinal: false
            ),
            revision: 1
        )
        let storage = FixtureStorage(pending: [revision])
        let synchronizer = TranscriptOutboxSynchronizer(
            storage: storage,
            uploader: FixtureUploader(accepted: 0)
        )
        await #expect(throws: TranscriptPersistenceError.invalidResponse) {
            _ = try await synchronizer.flush(workspaceID: UUID(), meetingID: meetingID)
        }
        #expect(await storage.acknowledged.isEmpty)
    }
}

private actor FixtureStorage: TranscriptRevisionStorage {
    let pending: [TranscriptSegmentRevision]
    private(set) var acknowledged: [TranscriptRevisionReference] = []

    init(pending: [TranscriptSegmentRevision]) {
        self.pending = pending
    }

    func persist(_: [TranscriptSegmentRevision]) async throws {}
    func transcript(for _: UUID) async throws -> [TranscriptSegmentRevision] {
        []
    }

    func pendingUpload(for _: UUID, limit _: Int) async throws -> [TranscriptSegmentRevision] {
        pending
    }

    func markUploaded(_ revisions: [TranscriptRevisionReference]) async throws {
        acknowledged = revisions
    }

    func deleteTranscript(meetingID _: UUID) async throws {}
}

private actor FixtureUploader: TranscriptBatchUploading {
    let accepted: Int

    init(accepted: Int) {
        self.accepted = accepted
    }

    func upload(
        workspaceID _: UUID,
        meetingID _: UUID,
        revisions _: [TranscriptSegmentRevision]
    ) async throws -> Int {
        accepted
    }
}
