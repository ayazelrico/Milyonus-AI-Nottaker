import Foundation

public actor BackendSTTTokenClient: STTTokenProvider {
    public typealias Fetch = @Sendable (URLRequest) async throws -> (Data, URLResponse)
    public typealias AuthorizationProvider = @Sendable () async throws -> String

    private struct TokenResponse: Decodable {
        let provider: String
        let accessToken: String
        let tokenType: String
        let expiresIn: TimeInterval
    }

    private let endpoint: URL
    private let authorizationProvider: AuthorizationProvider
    private let fetch: Fetch

    public init(
        baseURL: URL,
        authorizationProvider: @escaping AuthorizationProvider,
        fetch: @escaping Fetch = { try await URLSession.shared.data(for: $0) }
    ) {
        endpoint = baseURL.appendingPathComponent("v1/stt/token")
        self.authorizationProvider = authorizationProvider
        self.fetch = fetch
    }

    public func token(consentConfirmed: Bool) async throws -> STTAccessToken {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 10
        let authorization = try await authorizationProvider()
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["consentConfirmed": consentConfirmed])

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await fetch(request)
        } catch {
            throw STTTokenError.unavailable
        }

        guard let http = response as? HTTPURLResponse else {
            throw STTTokenError.invalidResponse
        }
        switch http.statusCode {
        case 200:
            break
        case 401:
            throw STTTokenError.unauthorized
        case 403:
            throw STTTokenError.entitlementRequired
        case 409:
            throw STTTokenError.consentRequired
        case 500 ... 599:
            throw STTTokenError.unavailable
        default:
            throw STTTokenError.invalidResponse
        }

        guard data.count <= 16384,
              let payload = try? JSONDecoder().decode(TokenResponse.self, from: data),
              payload.provider == "deepgram",
              payload.tokenType == "Bearer"
        else {
            throw STTTokenError.invalidResponse
        }
        return try STTAccessToken(value: payload.accessToken, expiresIn: payload.expiresIn)
    }
}
