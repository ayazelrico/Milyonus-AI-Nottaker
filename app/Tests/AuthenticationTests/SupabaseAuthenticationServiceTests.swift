import Auth
@testable import Authentication
import Foundation
import Shared
import Testing

@Suite("Supabase authentication adapter")
struct SupabaseAuthenticationServiceTests {
    @Test func requestsAPKCEProtectedMagicLinkWithoutPersistingEmail() async throws {
        let recorder = RequestRecorder()
        let service = try makeService { request in
            await recorder.append(request)
            return try response(for: request, status: 200, body: "{}")
        }

        try await service.requestMagicLink(email: "  PERSON@EXAMPLE.COM ")

        let request = try #require(await recorder.requests.first)
        #expect(request.url?.path == "/auth/v1/otp")
        let redirectURL = try URLComponents(url: #require(request.url), resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "redirect_to" })?
            .value
        #expect(redirectURL == "milyonus-nottaker://auth/callback")
        #expect(request.value(forHTTPHeaderField: "apikey") == "sb_publishable_fixture")
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["email"] as? String == "person@example.com")
        #expect(json["create_user"] as? Bool == true)
        #expect(json["code_challenge"] is String)
        #expect(json["code_challenge_method"] as? String == "s256")
    }

    @Test func rejectsInvalidEmailAndCallbackBeforeNetworkAccess() async throws {
        let recorder = RequestRecorder()
        let service = try makeService { request in
            await recorder.append(request)
            return try response(for: request, status: 500, body: "{}")
        }

        await #expect(throws: AuthenticationError.invalidEmail) {
            try await service.requestMagicLink(email: "not-an-email")
        }
        let callbackURL = try #require(URL(string: "https://attacker.example/callback?code=fixture"))
        await #expect(throws: AuthenticationError.invalidCallback) {
            try await service.completeSignIn(callbackURL: callbackURL)
        }
        #expect(await recorder.requests.isEmpty)
    }

    @Test func emptyKeychainHasNoCurrentSession() async throws {
        let service = try makeService { request in
            try response(for: request, status: 500, body: "{}")
        }
        #expect(try await service.currentSession() == nil)
    }

    private func makeService(fetch: @escaping AuthClient.FetchHandler) throws -> SupabaseAuthenticationService {
        let supabaseURL = try #require(URL(string: "https://project.supabase.co"))
        return try SupabaseAuthenticationService(
            configuration: AuthConfiguration(
                supabaseURL: supabaseURL,
                publishableKey: "sb_publishable_fixture"
            ),
            localStorage: MemoryStorage(),
            fetch: fetch
        )
    }
}

private actor RequestRecorder {
    private(set) var requests: [URLRequest] = []

    func append(_ request: URLRequest) {
        requests.append(request)
    }
}

private final class MemoryStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func store(key: String, value: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        values[key] = value
    }

    func retrieve(key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    func remove(key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        values[key] = nil
    }
}

private func response(for request: URLRequest, status: Int, body: String) throws -> (Data, URLResponse) {
    let url = try #require(request.url)
    let response = try #require(HTTPURLResponse(
        url: url,
        statusCode: status,
        httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": "application/json"]
    ))
    return (Data(body.utf8), response)
}
