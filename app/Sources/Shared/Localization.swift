import Foundation

public enum AppLanguage: String, CaseIterable, Sendable, Codable, Identifiable {
    case english = "en"
    case turkish = "tr"

    public static let defaultLanguage: AppLanguage = .english

    public var id: String {
        rawValue
    }

    public init(preference: String?) {
        self = preference.flatMap(Self.init(rawValue:)) ?? Self.defaultLanguage
    }
}

public enum AppStrings {
    /// Used by bundled-app validation to detect accidental fallback to a development build path.
    public static var resourceBundleURL: URL {
        resources.bundleURL
    }

    public static func text(_ key: String, language: AppLanguage = .defaultLanguage) -> String {
        let fallback = translation(key, language: .english) ?? key
        return translation(key, language: language) ?? fallback
    }

    private static func translation(_ key: String, language: AppLanguage) -> String? {
        guard let path = resources.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else {
            return nil
        }

        // A sentinel distinguishes an absent entry from a translation that equals its key.
        let missing = "__MILYONUS_MISSING_TRANSLATION__"
        let value = bundle.localizedString(forKey: key, value: missing, table: "Localizable")
        return value == missing ? nil : value
    }

    private static let resources: Bundle = {
        let resourceURL = Bundle.main.resourceURL?
            .appendingPathComponent("MilyonusNottaker_Shared.bundle")
        if let resourceURL, let packagedBundle = Bundle(url: resourceURL) {
            return packagedBundle
        }
        return Bundle.module
    }()
}
