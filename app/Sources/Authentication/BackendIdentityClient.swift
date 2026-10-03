import Foundation
import Shared

public enum BackendIdentityError: Error, Sendable, Equatable {
    case invalidResponse
    case unauthorized
    case identityMismatch
}

public actor BackendIdentityClient: AccountIdentityService {
    public typealias Fetch = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private struct IdentityResponse: Decodable {
        struct User: Decodable {
            let id: UUID
        }

        let user: User
    }

    private let endpoint: URL
    private let fetch: Fetch

    public init(baseURL: URL, fetch: @escaping Fetch = { try await URLSession.shared.data(for: $0) }) {
        endpoint = baseURL.appendingPathComponent("v1/me")
        self.fetch = fetch
    }

    public func identity(for session: AuthSession) async throws -> AccountIdentity {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue(session.authorizationValue(), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await fetch(request)
        guard let http = response as? HTTPURLResponse else {
            throw BackendIdentityError.invalidResponse
        }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 {
                throw BackendIdentityError.unauthorized
            }
            throw BackendIdentityError.invalidResponse
        }
        guard let payload = try? JSONDecoder().decode(IdentityResponse.self, from: data) else {
            throw BackendIdentityError.invalidResponse
        }
        guard payload.user.id == session.userID else {
            throw BackendIdentityError.identityMismatch
        }
        return AccountIdentity(userID: payload.user.id)
    }
}
