import Foundation
import Shared

public actor TranscriptOutboxSynchronizer {
    private let storage: any TranscriptRevisionStorage
    private let uploader: any TranscriptBatchUploading

    public init(
        storage: any TranscriptRevisionStorage,
        uploader: any TranscriptBatchUploading
    ) {
        self.storage = storage
        self.uploader = uploader
    }

    @discardableResult
    public func flush(workspaceID: UUID, meetingID: UUID, limit: Int = 100) async throws -> Int {
        let pending = try await storage.pendingUpload(for: meetingID, limit: limit)
        guard !pending.isEmpty else { return 0 }
        let accepted = try await uploader.upload(
            workspaceID: workspaceID,
            meetingID: meetingID,
            revisions: pending
        )
        guard accepted == pending.count else { throw TranscriptPersistenceError.invalidResponse }
        let references = try pending.map {
            try TranscriptRevisionReference(segmentID: $0.id, revision: $0.revision)
        }
        try await storage.markUploaded(references)
        return accepted
    }
}
