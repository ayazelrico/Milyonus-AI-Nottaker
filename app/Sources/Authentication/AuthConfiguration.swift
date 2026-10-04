import Foundation

public enum AuthConfigurationError: Error, Sendable, Equatable {
    case incomplete
    case invalidSupabaseURL
    case invalidPublishableKey
    case invalidBackendURL
}

public struct AuthConfiguration: Sendable, CustomStringConvertible {
    public static let callbackURL = URL(string: "milyonus-nottaker://auth/callback")!

    public let supabaseURL: URL
    public let backendBaseURL: URL?
    let publishableKey: String

    public var description: String {
        "AuthConfiguration(supabaseURL: \(supabaseURL.absoluteString), credentials: <redacted>)"
    }

    public init(supabaseURL: URL, publishableKey: String, backendBaseURL: URL? = nil) throws {
        guard Self.isSafeSupabaseURL(supabaseURL) else {
            throw AuthConfigurationError.invalidSupabaseURL
        }
        guard publishableKey.hasPrefix("sb_publishable_"), publishableKey.count <= 512 else {
            throw AuthConfigurationError.invalidPublishableKey
        }
        if let backendBaseURL, !Self.isSafeBackendURL(backendBaseURL) {
            throw AuthConfigurationError.invalidBackendURL
        }

        self.supabaseURL = supabaseURL
        self.publishableKey = publishableKey
        self.backendBaseURL = backendBaseURL
    }

    public static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundleValues: [String: Any] = Bundle.main.infoDictionary ?? [:]
    ) throws -> Self? {
        let urlValue = configurationValue(
            environmentName: "SUPABASE_URL",
            bundleName: "MilyonusSupabaseURL",
            environment: environment,
            bundleValues: bundleValues
        )
        let keyValue = configurationValue(
            environmentName: "SUPABASE_PUBLISHABLE_KEY",
            bundleName: "MilyonusSupabasePublishableKey",
            environment: environment,
            bundleValues: bundleValues
        )
        let hasURL = urlValue?.isEmpty == false
        let hasKey = keyValue?.isEmpty == false

        guard hasURL || hasKey else { return nil }
        guard hasURL, hasKey, let urlValue, let keyValue, let supabaseURL = URL(string: urlValue) else {
            throw AuthConfigurationError.incomplete
        }

        let backendURL: URL?
        let backendValue = configurationValue(
            environmentName: "BACKEND_BASE_URL",
            bundleName: "MilyonusBackendBaseURL",
            environment: environment,
            bundleValues: bundleValues
        )
        if let value = backendValue, !value.isEmpty {
            guard let parsed = URL(string: value) else { throw AuthConfigurationError.invalidBackendURL }
            backendURL = parsed
        } else {
            backendURL = nil
        }

        return try Self(
            supabaseURL: supabaseURL,
            publishableKey: keyValue,
            backendBaseURL: backendURL
        )
    }

    public func acceptsCallback(_ url: URL) -> Bool {
        guard let expected = URLComponents(url: Self.callbackURL, resolvingAgainstBaseURL: false),
              let candidate = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return false
        }
        return candidate.scheme == expected.scheme
            && candidate.host == expected.host
            && candidate.path == expected.path
            && candidate.user == nil
            && candidate.password == nil
    }

    var authURL: URL {
        supabaseURL.appendingPathComponent("auth/v1")
    }

    private static func isSafeSupabaseURL(_ url: URL) -> Bool {
        guard url.scheme == "https",
              let host = url.host,
              host.hasSuffix(".supabase.co"),
              url.user == nil,
              url.password == nil,
              url.query == nil,
              url.fragment == nil
        else {
            return false
        }
        return url.path.isEmpty || url.path == "/"
    }

    private static func isSafeBackendURL(_ url: URL) -> Bool {
        guard let host = url.host,
              url.user == nil,
              url.password == nil,
              url.query == nil,
              url.fragment == nil,
              url.path.isEmpty || url.path == "/"
        else {
            return false
        }
        if url.scheme == "https" {
            return true
        }
        return url.scheme == "http" && (host == "localhost" || host == "127.0.0.1" || host == "::1")
    }

    private static func configurationValue(
        environmentName: String,
        bundleName: String,
        environment: [String: String],
        bundleValues: [String: Any]
    ) -> String? {
        let environmentValue = environment[environmentName]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let environmentValue, !environmentValue.isEmpty {
            return environmentValue
        }
        return (bundleValues[bundleName] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
