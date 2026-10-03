import Authentication
import Foundation
import Testing

@Suite("Authentication configuration")
struct AuthConfigurationTests {
    @Test func loadsSafeRuntimeConfigurationWithoutExposingTheKey() throws {
        let loadedConfiguration = try AuthConfiguration.load(environment: [
            "SUPABASE_URL": "https://project.supabase.co",
            "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_fixture",
            "BACKEND_BASE_URL": "http://127.0.0.1:3000",
        ])
        let configuration = try #require(loadedConfiguration)

        #expect(configuration.supabaseURL.absoluteString == "https://project.supabase.co")
        #expect(configuration.backendBaseURL?.absoluteString == "http://127.0.0.1:3000")
        #expect(!configuration.description.contains("sb_publishable_fixture"))
    }

    @Test func absentConfigurationIsAllowedButPartialConfigurationFails() throws {
        #expect(try AuthConfiguration.load(environment: [:], bundleValues: [:]) == nil)
        #expect(throws: AuthConfigurationError.incomplete) {
            try AuthConfiguration.load(
                environment: ["SUPABASE_URL": "https://project.supabase.co"],
                bundleValues: [:]
            )
        }
    }

    @Test func loadsPackagedConfigurationWhenEnvironmentIsAbsent() throws {
        let loadedConfiguration = try AuthConfiguration.load(environment: [:], bundleValues: [
            "MilyonusSupabaseURL": "https://project.supabase.co",
            "MilyonusSupabasePublishableKey": "sb_publishable_fixture",
            "MilyonusBackendBaseURL": "https://api.example.com",
        ])
        let configuration = try #require(loadedConfiguration)

        #expect(configuration.supabaseURL.absoluteString == "https://project.supabase.co")
        #expect(configuration.backendBaseURL?.absoluteString == "https://api.example.com")
    }

    @Test(arguments: [
        "http://project.supabase.co",
        "https://project.supabase.co/path",
        "https://name:password@project.supabase.co",
        "https://project.example.com",
    ])
    func rejectsUnsafeSupabaseURLs(value: String) throws {
        let url = try #require(URL(string: value))
        #expect(throws: AuthConfigurationError.invalidSupabaseURL) {
            try AuthConfiguration(supabaseURL: url, publishableKey: "sb_publishable_fixture")
        }
    }

    @Test func callbackMustMatchTheRegisteredApplicationRoute() throws {
        let supabaseURL = try #require(URL(string: "https://project.supabase.co"))
        let validCallback = try #require(URL(string: "milyonus-nottaker://auth/callback?code=fixture"))
        let wrongHost = try #require(URL(string: "milyonus-nottaker://attacker/callback?code=fixture"))
        let wrongScheme = try #require(URL(string: "https://example.com/auth/callback?code=fixture"))
        let configuration = try AuthConfiguration(
            supabaseURL: supabaseURL,
            publishableKey: "sb_publishable_fixture"
        )
        #expect(configuration.acceptsCallback(validCallback))
        #expect(!configuration.acceptsCallback(wrongHost))
        #expect(!configuration.acceptsCallback(wrongScheme))
    }
}
