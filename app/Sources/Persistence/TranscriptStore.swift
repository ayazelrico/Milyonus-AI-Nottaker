import CryptoKit
import Foundation
import GRDB
import Shared

public actor TranscriptStore: TranscriptRevisionStorage {
    private struct EncryptedRevision {
        let revision: TranscriptSegmentRevision
        let ciphertext: Data
    }

    private let database: DatabaseQueue
    private let keyData: Data

    public init(databaseURL: URL, keyProvider: any TranscriptEncryptionKeyProvider) async throws {
        let keyData = try await keyProvider.keyData()
        guard keyData.count == 32 else { throw TranscriptPersistenceError.invalidEncryptionKey }
        database = try DatabaseQueue(path: databaseURL.path)
        self.keyData = keyData
        try Self.migrator.migrate(database)
    }

    public static func applicationSupport(
        keyProvider: any TranscriptEncryptionKeyProvider = KeychainTranscriptKeyProvider()
    ) async throws -> TranscriptStore {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseURL.appendingPathComponent("com.milyonus.nottaker", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try await TranscriptStore(
            databaseURL: directory.appendingPathComponent("transcripts.sqlite"),
            keyProvider: keyProvider
        )
    }

    public func persist(_ revisions: [TranscriptSegmentRevision]) async throws {
        let encrypted = try revisions.map { revision in
            try EncryptedRevision(revision: revision, ciphertext: encrypt(revision.segment.text))
        }
        try await database.write { database in
            for item in encrypted {
                try Self.write(item, to: database)
            }
        }
    }

    private static func write(_ item: EncryptedRevision, to database: Database) throws {
        let segment = item.revision.segment
        if let existing = try Row.fetchOne(
            database,
            sql: "SELECT meeting_id, channel, is_final, revision FROM transcript_segments_local WHERE id = ?",
            arguments: [segment.id.uuidString.lowercased()]
        ) {
            try validate(existing: existing, against: item.revision)
        }
        try database.execute(
            sql: """
            INSERT INTO transcript_segments_local
                (id, meeting_id, channel, ciphertext, start_ms, end_ms, is_final, revision)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                ciphertext = excluded.ciphertext,
                start_ms = excluded.start_ms,
                end_ms = excluded.end_ms,
                is_final = excluded.is_final,
                revision = excluded.revision
            WHERE excluded.revision > transcript_segments_local.revision
              AND transcript_segments_local.meeting_id = excluded.meeting_id
              AND transcript_segments_local.channel = excluded.channel
              AND (transcript_segments_local.is_final = 0 OR excluded.is_final = 1)
            """,
            arguments: [
                segment.id.uuidString.lowercased(),
                segment.meetingID.uuidString.lowercased(),
                segment.channel.rawValue,
                item.ciphertext,
                segment.startMilliseconds,
                segment.endMilliseconds,
                segment.isFinal,
                item.revision.revision,
            ]
        )
        guard database.changesCount == 1 else { return }
        try database.execute(
            sql: """
            INSERT INTO transcript_outbox (segment_id, revision)
            VALUES (?, ?)
            ON CONFLICT(segment_id) DO UPDATE SET revision = excluded.revision
            WHERE excluded.revision > transcript_outbox.revision
            """,
            arguments: [segment.id.uuidString.lowercased(), item.revision.revision]
        )
    }

    private static func validate(existing: Row, against revision: TranscriptSegmentRevision) throws {
        let existingMeetingID: String = existing["meeting_id"]
        let existingChannel: String = existing["channel"]
        let existingIsFinal: Bool = existing["is_final"]
        let existingRevision: Int = existing["revision"]
        guard existingMeetingID == revision.segment.meetingID.uuidString.lowercased(),
              existingChannel == revision.segment.channel.rawValue
        else {
            throw TranscriptPersistenceError.segmentIdentityChanged
        }
        guard revision.revision <= existingRevision || !existingIsFinal || revision.segment.isFinal else {
            throw TranscriptPersistenceError.finalityRegression
        }
    }

    public func transcript(for meetingID: UUID) async throws -> [TranscriptSegmentRevision] {
        let keyData = keyData
        return try await database.read { database in
            let rows = try Row.fetchAll(
                database,
                sql: """
                SELECT id, meeting_id, channel, ciphertext, start_ms, end_ms, is_final, revision
                FROM transcript_segments_local
                WHERE meeting_id = ?
                ORDER BY start_ms, end_ms, channel, id
                """,
                arguments: [meetingID.uuidString.lowercased()]
            )
            return try rows.map { try Self.decode(row: $0, keyData: keyData) }
        }
    }

    public func pendingUpload(
        for meetingID: UUID,
        limit: Int
    ) async throws -> [TranscriptSegmentRevision] {
        guard (1 ... 100).contains(limit) else { throw TranscriptPersistenceError.invalidBatch }
        let keyData = keyData
        return try await database.read { database in
            let rows = try Row.fetchAll(
                database,
                sql: """
                SELECT s.id, s.meeting_id, s.channel, s.ciphertext,
                       s.start_ms, s.end_ms, s.is_final, s.revision
                FROM transcript_outbox AS o
                JOIN transcript_segments_local AS s ON s.id = o.segment_id
                WHERE s.meeting_id = ? AND s.revision = o.revision
                ORDER BY s.start_ms, s.end_ms, s.channel, s.id
                LIMIT ?
                """,
                arguments: [meetingID.uuidString.lowercased(), limit]
            )
            return try rows.map { try Self.decode(row: $0, keyData: keyData) }
        }
    }

    public func markUploaded(_ revisions: [TranscriptRevisionReference]) async throws {
        try await database.write { database in
            for revision in revisions {
                try database.execute(
                    sql: "DELETE FROM transcript_outbox WHERE segment_id = ? AND revision <= ?",
                    arguments: [revision.segmentID.uuidString.lowercased(), revision.revision]
                )
            }
        }
    }

    public func deleteTranscript(meetingID: UUID) async throws {
        try await database.write { database in
            try database.execute(
                sql: "DELETE FROM transcript_segments_local WHERE meeting_id = ?",
                arguments: [meetingID.uuidString.lowercased()]
            )
        }
    }

    private static func decode(row: Row, keyData: Data) throws -> TranscriptSegmentRevision {
        guard let id = UUID(uuidString: row["id"]),
              let meetingID = UUID(uuidString: row["meeting_id"]),
              let channel = AudioChannel(rawValue: row["channel"])
        else {
            throw TranscriptPersistenceError.decryptionFailed
        }
        let ciphertext: Data = row["ciphertext"]
        let segment = try TranscriptSegment(
            id: id,
            meetingID: meetingID,
            channel: channel,
            text: decrypt(ciphertext, keyData: keyData),
            startMilliseconds: row["start_ms"],
            endMilliseconds: row["end_ms"],
            isFinal: row["is_final"]
        )
        return try TranscriptSegmentRevision(segment: segment, revision: row["revision"])
    }

    private func encrypt(_ text: String) throws -> Data {
        do {
            let sealed = try AES.GCM.seal(
                Data(text.utf8),
                using: SymmetricKey(data: keyData)
            )
            guard let combined = sealed.combined else {
                throw TranscriptPersistenceError.encryptionFailed
            }
            return combined
        } catch {
            throw TranscriptPersistenceError.encryptionFailed
        }
    }

    private static func decrypt(_ ciphertext: Data, keyData: Data) throws -> String {
        do {
            let box = try AES.GCM.SealedBox(combined: ciphertext)
            let plaintext = try AES.GCM.open(box, using: SymmetricKey(data: keyData))
            guard let text = String(data: plaintext, encoding: .utf8) else {
                throw TranscriptPersistenceError.decryptionFailed
            }
            return text
        } catch {
            throw TranscriptPersistenceError.decryptionFailed
        }
    }

    private static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createEncryptedTranscriptStore") { database in
            try database.execute(sql: """
            CREATE TABLE transcript_segments_local (
                id TEXT PRIMARY KEY NOT NULL,
                meeting_id TEXT NOT NULL,
                channel TEXT NOT NULL CHECK (channel IN ('microphone', 'system')),
                ciphertext BLOB NOT NULL,
                start_ms INTEGER NOT NULL CHECK (start_ms >= 0),
                end_ms INTEGER NOT NULL CHECK (end_ms >= start_ms),
                is_final INTEGER NOT NULL CHECK (is_final IN (0, 1)),
                revision INTEGER NOT NULL CHECK (revision > 0)
            );
            CREATE INDEX transcript_segments_local_timeline_idx
                ON transcript_segments_local (meeting_id, start_ms, channel);
            CREATE TABLE transcript_outbox (
                segment_id TEXT PRIMARY KEY NOT NULL
                    REFERENCES transcript_segments_local(id) ON DELETE CASCADE,
                revision INTEGER NOT NULL CHECK (revision > 0)
            );
            """)
        }
        return migrator
    }
}
