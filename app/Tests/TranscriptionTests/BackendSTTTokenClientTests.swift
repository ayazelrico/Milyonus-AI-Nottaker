import Foundation
import Testing
@testable import Transcription

@Suite("Backend STT token client")
struct BackendSTTTokenClientTests {
    @Test func requestsAConsentedTokenWithOneAuthorizationHeader() async throws {
        let recorder = RequestRecorder()
        let baseURL = try #require(URL(string: "https://api.example.com"))
        let client = BackendSTTTokenClient(
            baseURL: baseURL,
            authorizationProvider: { "Bearer private-session-fixture" },
            fetch: { request in
                await recorder.append(request)
                let url = try #require(request.url)
                let response = try #require(HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                ))
                let body = """
                {"provider":"deepgram","accessToken":"header.payload.signature","tokenType":"Bearer","expiresIn":30}
                """
                return (Data(body.utf8), response)
            }
        )

        let token = try await client.token(consentConfirmed: true)

        #expect(token.authorizationValue() == "Bearer header.payload.signature")
        #expect(!token.description.contains("header.payload.signature"))
        let request = try #require(await recorder.requests.first)
        #expect(request.url?.absoluteString == "https://api.example.com/v1/stt/token")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer private-session-fixture")
        #expect(request.allHTTPHeaderFields?.keys.filter { $0.lowercased() == "authorization" }.count == 1)
        let body = try #require(request.httpBody)
        #expect(try JSONSerialization.jsonObject(with: body) as? [String: Bool] == ["consentConfirmed": true])
    }

    @Test(arguments: [
        (401, STTTokenError.unauthorized),
        (403, STTTokenError.entitlementRequired),
        (409, STTTokenError.consentRequired),
        (503, STTTokenError.unavailable),
        (418, STTTokenError.invalidResponse),
    ])
    func mapsStatusWithoutDecodingProviderDetails(status: Int, expected: STTTokenError) async throws {
        let baseURL = try #require(URL(string: "https://api.example.com"))
        let client = BackendSTTTokenClient(
            baseURL: baseURL,
            authorizationProvider: { "Bearer session.fixture.token" },
            fetch: { request in
                let url = try #require(request.url)
                let response = try #require(HTTPURLResponse(
                    url: url,
                    statusCode: status,
                    httpVersion: "HTTP/1.1",
                    headerFields: nil
                ))
                return (Data("private-provider-fixture".utf8), response)
            }
        )

        await #expect(throws: expected) {
            try await client.token(consentConfirmed: true)
        }
    }

    @Test(arguments: [
        "not-a-token",
        "header.payload.",
        "header.payload.signature!",
    ])
    func rejectsUnsafeTokenValues(value: String) {
        #expect(throws: STTTokenError.invalidResponse) {
            try STTAccessToken(value: value, expiresIn: 30)
        }
    }
}

private actor RequestRecorder {
    private(set) var requests: [URLRequest] = []

    func append(_ request: URLRequest) {
        requests.append(request)
    }
}
