import Auth
import Foundation
import Shared

public enum AuthenticationError: Error, Sendable, Equatable {
    case invalidEmail
    case invalidCallback
    case emailAddressRequired
    case sessionUnavailable
}

public actor SupabaseAuthenticationService: AuthenticationService {
    private let configuration: AuthConfiguration
    private let client: AuthClient

    public init(configuration: AuthConfiguration) {
        self.configuration = configuration
        client = Self.makeClient(
            configuration: configuration,
            localStorage: KeychainLocalStorage(service: "com.milyonus.nottaker.auth")
        )
    }

    init(
        configuration: AuthConfiguration,
        localStorage: any AuthLocalStorage,
        fetch: @escaping AuthClient.FetchHandler
    ) {
        self.configuration = configuration
        client = Self.makeClient(configuration: configuration, localStorage: localStorage, fetch: fetch)
    }

    public func currentSession() async throws -> AuthSession? {
        guard client.currentSession != nil else { return nil }
        return try await mappedSession(client.session)
    }

    public func requestMagicLink(email: String) async throws {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.isValidEmail(normalized) else { throw AuthenticationError.invalidEmail }
        try await client.signInWithOTP(
            email: normalized,
            redirectTo: AuthConfiguration.callbackURL,
            shouldCreateUser: true
        )
    }

    public func completeSignIn(callbackURL: URL) async throws -> AuthSession {
        guard configuration.acceptsCallback(callbackURL) else {
            throw AuthenticationError.invalidCallback
        }
        return try await mappedSession(client.session(from: callbackURL))
    }

    public func signIn(using provider: SignInProvider) async throws -> AuthSession {
        let session: Session
        switch provider {
        case .apple:
            session = try await client.signInWithOAuth(provider: .apple)
        case .google:
            session = try await client.signInWithOAuth(provider: .google)
        case .email:
            throw AuthenticationError.emailAddressRequired
        }
        return try mappedSession(session)
    }

    public func signOut() async throws {
        try await client.signOut()
    }

    private func mappedSession(_ session: Session) throws -> AuthSession {
        try AuthSession(
            userID: session.user.id,
            accessToken: session.accessToken,
            expiresAt: Date(timeIntervalSince1970: session.expiresAt)
        )
    }

    private static func makeClient(
        configuration: AuthConfiguration,
        localStorage: any AuthLocalStorage,
        fetch: @escaping AuthClient.FetchHandler = { try await URLSession.shared.data(for: $0) }
    ) -> AuthClient {
        AuthClient(
            url: configuration.authURL,
            headers: [
                "apikey": configuration.publishableKey,
                "Authorization": "Bearer \(configuration.publishableKey)",
            ],
            flowType: .pkce,
            redirectToURL: AuthConfiguration.callbackURL,
            storageKey: "milyonus-nottaker-auth-session",
            localStorage: localStorage,
            logger: nil,
            fetch: fetch,
            autoRefreshToken: true,
            emitLocalSessionAsInitialSession: true
        )
    }

    private static func isValidEmail(_ value: String) -> Bool {
        guard value.count <= 254,
              !value.contains(where: \.isWhitespace)
        else {
            return false
        }
        let pieces = value.split(separator: "@", omittingEmptySubsequences: false)
        return pieces.count == 2
            && !pieces[0].isEmpty
            && pieces[1].contains(".")
            && !pieces[1].hasPrefix(".")
            && !pieces[1].hasSuffix(".")
    }
}
