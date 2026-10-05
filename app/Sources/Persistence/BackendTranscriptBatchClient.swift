import Foundation
import Shared

public actor BackendTranscriptBatchClient: TranscriptBatchUploading {
    public typealias Fetch = @Sendable (URLRequest) async throws -> (Data, URLResponse)
    public typealias AuthorizationProvider = @Sendable () async throws -> String

    private struct RequestBody: Encodable {
        let workspaceId: UUID
        let meetingId: UUID
        let segments: [Segment]
    }

    private struct Segment: Encodable {
        let id: UUID
        let channel: AudioChannel
        let text: String
        let startMilliseconds: Int
        let endMilliseconds: Int
        let isFinal: Bool
        let revision: Int
    }

    private struct ResponseBody: Decodable {
        let accepted: Int
    }

    private let endpoint: URL
    private let authorizationProvider: AuthorizationProvider
    private let fetch: Fetch

    public init(
        baseURL: URL,
        authorizationProvider: @escaping AuthorizationProvider,
        fetch: @escaping Fetch = { try await URLSession.shared.data(for: $0) }
    ) {
        endpoint = baseURL.appendingPathComponent("v1/transcript/segments:batch")
        self.authorizationProvider = authorizationProvider
        self.fetch = fetch
    }

    public func upload(
        workspaceID: UUID,
        meetingID: UUID,
        revisions: [TranscriptSegmentRevision]
    ) async throws -> Int {
        guard !revisions.isEmpty,
              revisions.count <= 100,
              revisions.allSatisfy({ $0.segment.meetingID == meetingID })
        else {
            throw TranscriptPersistenceError.invalidBatch
        }

        let body = RequestBody(
            workspaceId: workspaceID,
            meetingId: meetingID,
            segments: revisions.map {
                Segment(
                    id: $0.id,
                    channel: $0.segment.channel,
                    text: $0.segment.text,
                    startMilliseconds: $0.segment.startMilliseconds,
                    endMilliseconds: $0.segment.endMilliseconds,
                    isFinal: $0.segment.isFinal,
                    revision: $0.revision
                )
            }
        )
        let request = try await request(body: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await fetch(request)
        } catch {
            throw TranscriptPersistenceError.unavailable
        }
        return try acceptedCount(data: data, response: response, maximum: revisions.count)
    }

    private func request(body: RequestBody) async throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "PUT"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 15
        try await request.setValue(authorizationProvider(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func acceptedCount(data: Data, response: URLResponse, maximum: Int) throws -> Int {
        guard let http = response as? HTTPURLResponse else {
            throw TranscriptPersistenceError.invalidResponse
        }
        if http.statusCode == 401 {
            throw TranscriptPersistenceError.unauthorized
        }
        if (500 ... 599).contains(http.statusCode) {
            throw TranscriptPersistenceError.unavailable
        }
        guard http.statusCode == 200,
              data.count <= 16384,
              let payload = try? JSONDecoder().decode(ResponseBody.self, from: data),
              payload.accepted >= 0,
              payload.accepted <= maximum
        else {
            throw TranscriptPersistenceError.invalidResponse
        }
        return payload.accepted
    }
}
