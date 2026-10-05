import Foundation
import Shared

public actor SegmentAssembler {
    private var revisions: [UUID: TranscriptSegmentRevision] = [:]

    public init() {}

    /// Returns a revision only when the segment contains new durable state.
    public func ingest(_ segment: TranscriptSegment) throws -> TranscriptSegmentRevision? {
        guard let current = revisions[segment.id] else {
            let revision = try TranscriptSegmentRevision(segment: segment, revision: 1)
            revisions[segment.id] = revision
            return revision
        }

        guard current.segment.meetingID == segment.meetingID,
              current.segment.channel == segment.channel
        else {
            throw TranscriptPersistenceError.segmentIdentityChanged
        }
        guard !current.segment.isFinal || segment.isFinal else {
            throw TranscriptPersistenceError.finalityRegression
        }
        guard current.segment != segment else { return nil }

        let revision = try TranscriptSegmentRevision(
            segment: segment,
            revision: current.revision + 1
        )
        revisions[segment.id] = revision
        return revision
    }

    public func seed(_ storedRevisions: [TranscriptSegmentRevision]) throws {
        for stored in storedRevisions {
            if let current = revisions[stored.id], current.revision >= stored.revision {
                continue
            }
            if let current = revisions[stored.id] {
                guard current.segment.meetingID == stored.segment.meetingID,
                      current.segment.channel == stored.segment.channel
                else {
                    throw TranscriptPersistenceError.segmentIdentityChanged
                }
            }
            revisions[stored.id] = stored
        }
    }

    public func removeAll() {
        revisions.removeAll(keepingCapacity: false)
    }
}
