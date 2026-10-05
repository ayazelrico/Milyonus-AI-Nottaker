import Foundation
import Persistence
import Shared
import Testing

@Suite("Backend transcript batch client")
struct BackendTranscriptBatchClientTests {
    @Test("Uploads an authenticated bounded batch")
    func upload() async throws {
        let meetingID = UUID()
        let workspaceID = UUID()
        let revision = try fixtureRevision(meetingID: meetingID)
        let recorder = RequestRecorder()
        let client = try BackendTranscriptBatchClient(
            baseURL: #require(URL(string: "https://api.example.test")),
            authorizationProvider: { "Bearer private-session-fixture" },
            fetch: { request in
                await recorder.record(request)
                return (
                    Data(#"{"accepted":1}"#.utf8),
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!
                )
            }
        )

        #expect(try await client.upload(
            workspaceID: workspaceID,
            meetingID: meetingID,
            revisions: [revision]
        ) == 1)
        let request = try #require(await recorder.request)
        #expect(request.httpMethod == "PUT")
        #expect(request.url?.path == "/v1/transcript/segments:batch")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer private-session-fixture")
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["workspaceId"] as? String == workspaceID.uuidString)
        #expect(json["meetingId"] as? String == meetingID.uuidString)
        let segments = try #require(json["segments"] as? [[String: Any]])
        #expect(segments.first?["revision"] as? Int == 1)
        #expect(segments.first?["text"] as? String == "fixture transcript")
    }

    @Test("Keeps provider details out of transport failures")
    func redactedFailure() async throws {
        let meetingID = UUID()
        let client = try BackendTranscriptBatchClient(
            baseURL: #require(URL(string: "https://api.example.test")),
            authorizationProvider: { "Bearer fixture" },
            fetch: { _ in throw NSError(domain: "private-provider-fixture", code: 1) }
        )
        await #expect(throws: TranscriptPersistenceError.unavailable) {
            _ = try await client.upload(
                workspaceID: UUID(),
                meetingID: meetingID,
                revisions: [fixtureRevision(meetingID: meetingID)]
            )
        }
    }

    private func fixtureRevision(meetingID: UUID) throws -> TranscriptSegmentRevision {
        try TranscriptSegmentRevision(
            segment: TranscriptSegment(
                meetingID: meetingID,
                channel: .microphone,
                text: "fixture transcript",
                startMilliseconds: 0,
                endMilliseconds: 200,
                isFinal: true
            ),
            revision: 1
        )
    }
}

private actor RequestRecorder {
    private(set) var request: URLRequest?

    func record(_ request: URLRequest) {
        self.request = request
    }
}
