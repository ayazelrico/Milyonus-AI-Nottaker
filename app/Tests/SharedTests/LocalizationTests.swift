import Shared
import Testing

struct LocalizationTests {
    @Test func englishIsTheDefaultForMissingOrUnsupportedPreference() {
        #expect(AppLanguage.defaultLanguage == .english)
        #expect(AppLanguage(preference: nil) == .english)
        #expect(AppLanguage(preference: "de") == .english)
        #expect(AppLanguage(preference: "tr") == .turkish)
    }

    @Test func englishStringsLoadFromPackageResources() {
        #expect(AppStrings.text("Workspace") == "Workspace")
        #expect(AppStrings.text("Settings") == "Settings")
    }

    @Test func turkishStringsLoadFromPackageResources() {
        #expect(AppStrings.text("Workspace", language: .turkish) == "Çalışma alanı")
        #expect(AppStrings.text("Settings", language: .turkish) == "Ayarlar")
    }

    @Test func missingTranslationFallsBackToEnglishSourceKey() {
        let source = "An English source string absent from the catalog"
        #expect(AppStrings.text(source, language: .turkish) == source)
    }
}
