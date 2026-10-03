import Authentication
import Foundation
import Shared
import Testing

@Suite("Backend identity client")
struct BackendIdentityClientTests {
    @Test func verifiesTheSignedIdentityWithOneBearerHeader() async throws {
        let userID = try #require(UUID(uuidString: "44757ce8-0661-49d0-aaf7-4567e0808c0a"))
        let recorder = IdentityRequestRecorder()
        let baseURL = try #require(URL(string: "https://api.example.com"))
        let client = BackendIdentityClient(
            baseURL: baseURL,
            fetch: { request in
                await recorder.append(request)
                let requestURL = try #require(request.url)
                let response = try #require(HTTPURLResponse(
                    url: requestURL,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                ))
                return (Data("{\"user\":{\"id\":\"\(userID.uuidString)\"}}".utf8), response)
            }
        )
        let session = try AuthSession(
            userID: userID,
            accessToken: "private-token-fixture",
            expiresAt: Date().addingTimeInterval(300)
        )

        let identity = try await client.identity(for: session)

        #expect(identity == AccountIdentity(userID: userID))
        let request = try #require(await recorder.requests.first)
        #expect(request.url?.absoluteString == "https://api.example.com/v1/me")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer private-token-fixture")
        #expect(request.allHTTPHeaderFields?.keys.filter { $0.lowercased() == "authorization" }.count == 1)
    }

    @Test func rejectsAResponseForAnotherUser() async throws {
        let sessionUser = try #require(UUID(uuidString: "44757ce8-0661-49d0-aaf7-4567e0808c0a"))
        let otherUser = try #require(UUID(uuidString: "55757ce8-0661-49d0-aaf7-4567e0808c0a"))
        let baseURL = try #require(URL(string: "https://api.example.com"))
        let client = BackendIdentityClient(
            baseURL: baseURL,
            fetch: { request in
                let requestURL = try #require(request.url)
                let response = try #require(HTTPURLResponse(
                    url: requestURL,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: nil
                ))
                return (Data("{\"user\":{\"id\":\"\(otherUser.uuidString)\"}}".utf8), response)
            }
        )
        let session = try AuthSession(
            userID: sessionUser,
            accessToken: "private-token-fixture",
            expiresAt: Date().addingTimeInterval(300)
        )

        await #expect(throws: BackendIdentityError.identityMismatch) {
            try await client.identity(for: session)
        }
    }
}

private actor IdentityRequestRecorder {
    private(set) var requests: [URLRequest] = []

    func append(_ request: URLRequest) {
        requests.append(request)
    }
}
