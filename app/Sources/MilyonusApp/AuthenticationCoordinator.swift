import Authentication
import Foundation
import Observation
import Shared

enum AuthenticationState: Equatable {
    case notConfigured
    case signedOut
    case sendingMagicLink
    case checkEmail
    case signingIn
    case signedIn(userID: UUID)
}

@MainActor
@Observable
final class AuthenticationCoordinator {
    var email = "" {
        didSet {
            if email != oldValue {
                errorKey = nil
            }
        }
    }

    private(set) var state: AuthenticationState = .notConfigured
    private(set) var errorKey: String?

    private let service: (any AuthenticationService)?
    private let identityService: (any AccountIdentityService)?

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundleValues: [String: Any] = Bundle.main.infoDictionary ?? [:]
    ) {
        do {
            guard let configuration = try AuthConfiguration.load(
                environment: environment,
                bundleValues: bundleValues
            ) else {
                service = nil
                identityService = nil
                return
            }
            service = SupabaseAuthenticationService(configuration: configuration)
            identityService = configuration.backendBaseURL.map { BackendIdentityClient(baseURL: $0) }
            state = .signedOut
        } catch {
            service = nil
            identityService = nil
            errorKey = "Authentication configuration is invalid."
        }
    }

    var isBusy: Bool {
        state == .sendingMagicLink || state == .signingIn
    }

    var isSignedIn: Bool {
        if case .signedIn = state {
            return true
        }
        return false
    }

    func restoreSession() async {
        guard let service else { return }
        errorKey = nil
        do {
            guard let session = try await service.currentSession() else {
                state = .signedOut
                return
            }
            try await accept(session, using: service)
        } catch {
            state = .signedOut
            errorKey = "We could not restore your session. Please sign in again."
        }
    }

    func requestMagicLink() async {
        guard let service, !isBusy else { return }
        state = .sendingMagicLink
        errorKey = nil
        do {
            try await service.requestMagicLink(email: email)
            state = .checkEmail
        } catch AuthenticationError.invalidEmail {
            state = .signedOut
            errorKey = "Enter a valid email address."
        } catch {
            state = .signedOut
            errorKey = "We could not send the sign-in link. Please try again."
        }
    }

    func completeSignIn(callbackURL: URL) async {
        guard let service else { return }
        state = .signingIn
        errorKey = nil
        do {
            let session = try await service.completeSignIn(callbackURL: callbackURL)
            try await accept(session, using: service)
        } catch {
            state = .signedOut
            errorKey = "The sign-in link could not be completed. Request a new link."
        }
    }

    func signIn(using provider: SignInProvider) async {
        guard let service, !isBusy else { return }
        state = .signingIn
        errorKey = nil
        do {
            let session = try await service.signIn(using: provider)
            try await accept(session, using: service)
        } catch {
            state = .signedOut
            errorKey = "That sign-in method is not available yet."
        }
    }

    func signOut() async {
        guard let service, !isBusy else { return }
        errorKey = nil
        do {
            try await service.signOut()
            email = ""
            state = .signedOut
        } catch {
            errorKey = "We could not sign you out. Please try again."
        }
    }

    private func accept(_ session: AuthSession, using service: any AuthenticationService) async throws {
        if let identityService {
            do {
                _ = try await identityService.identity(for: session)
            } catch {
                try? await service.signOut()
                throw error
            }
        }
        state = .signedIn(userID: session.userID)
    }
}
