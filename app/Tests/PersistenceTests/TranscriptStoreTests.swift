import Foundation
import Persistence
import Shared
import Testing

@Suite("Encrypted transcript store")
struct TranscriptStoreTests {
    @Test("Persists encrypted text and manages exact outbox revisions")
    func persistenceAndOutbox() async throws {
        let context = try await makeStore()
        defer { try? FileManager.default.removeItem(at: context.directory) }
        let meetingID = UUID()
        let segmentID = UUID()
        let privateText = "private transcript fixture 7f72f14d"
        let first = try revision(
            id: segmentID,
            meetingID: meetingID,
            text: privateText,
            revision: 1,
            isFinal: false
        )
        try await context.store.persist([first])

        let stored = try await context.store.transcript(for: meetingID)
        #expect(stored == [first])
        #expect(try await context.store.pendingUpload(for: meetingID, limit: 100) == [first])

        let bytes = try persistedBytes(in: context.directory)
        #expect(!bytes.contains(Data(privateText.utf8)))

        let second = try revision(
            id: segmentID,
            meetingID: meetingID,
            text: "corrected final fixture",
            revision: 2,
            isFinal: true
        )
        try await context.store.persist([second])
        try await context.store.markUploaded([
            TranscriptRevisionReference(segmentID: segmentID, revision: 1),
        ])
        #expect(try await context.store.pendingUpload(for: meetingID, limit: 100) == [second])

        try await context.store.persist([first])
        #expect(try await context.store.transcript(for: meetingID) == [second])
        try await assertInvalidTransitions(
            store: context.store,
            segmentID: segmentID,
            meetingID: meetingID
        )
        try await context.store.markUploaded([
            TranscriptRevisionReference(segmentID: segmentID, revision: 2),
        ])
        #expect(try await context.store.pendingUpload(for: meetingID, limit: 100).isEmpty)
    }

    private func assertInvalidTransitions(
        store: TranscriptStore,
        segmentID: UUID,
        meetingID: UUID
    ) async throws {
        await #expect(throws: TranscriptPersistenceError.finalityRegression) {
            try await store.persist([
                revision(
                    id: segmentID,
                    meetingID: meetingID,
                    text: "regressed interim fixture",
                    revision: 3,
                    isFinal: false
                ),
            ])
        }
        await #expect(throws: TranscriptPersistenceError.segmentIdentityChanged) {
            try await store.persist([
                revision(
                    id: segmentID,
                    meetingID: UUID(),
                    text: "different meeting fixture",
                    revision: 3,
                    isFinal: true
                ),
            ])
        }
    }

    @Test("Deletes a meeting transcript and its outbox rows")
    func deletion() async throws {
        let context = try await makeStore()
        defer { try? FileManager.default.removeItem(at: context.directory) }
        let meetingID = UUID()
        try await context.store.persist([
            revision(id: UUID(), meetingID: meetingID, text: "delete fixture", revision: 1, isFinal: true),
        ])
        try await context.store.deleteTranscript(meetingID: meetingID)
        #expect(try await context.store.transcript(for: meetingID).isEmpty)
        #expect(try await context.store.pendingUpload(for: meetingID, limit: 100).isEmpty)
    }

    @Test("Rejects an invalid encryption key")
    func invalidKey() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        await #expect(throws: TranscriptPersistenceError.invalidEncryptionKey) {
            _ = try await TranscriptStore(
                databaseURL: directory.appendingPathComponent("test.sqlite"),
                keyProvider: FixtureKeyProvider(data: Data(repeating: 0, count: 31))
            )
        }
    }

    private func makeStore() async throws -> (store: TranscriptStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try await TranscriptStore(
            databaseURL: directory.appendingPathComponent("test.sqlite"),
            keyProvider: FixtureKeyProvider(data: Data(repeating: 7, count: 32))
        )
        return (store, directory)
    }

    private func revision(
        id: UUID,
        meetingID: UUID,
        text: String,
        revision: Int,
        isFinal: Bool
    ) throws -> TranscriptSegmentRevision {
        try TranscriptSegmentRevision(
            segment: TranscriptSegment(
                id: id,
                meetingID: meetingID,
                channel: .system,
                text: text,
                startMilliseconds: 100,
                endMilliseconds: 500,
                isFinal: isFinal
            ),
            revision: revision
        )
    }

    private func persistedBytes(in directory: URL) throws -> Data {
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        return try files.reduce(into: Data()) { result, url in
            try result.append(Data(contentsOf: url))
        }
    }
}

private struct FixtureKeyProvider: TranscriptEncryptionKeyProvider {
    let data: Data

    func keyData() async throws -> Data {
        data
    }
}
