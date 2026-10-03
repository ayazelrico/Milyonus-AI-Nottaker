import CoreText
import Foundation

/// Registers bundled OFL fonts for this process only; never installs fonts on the Mac.
public enum BrandFonts {
    public static let sansName = "InterTight-Regular"
    public static let serifName = "InstrumentSerif-Italic"

    public static var resourceBundleURL: URL {
        resources.bundleURL
    }

    @discardableResult
    public static func register() -> Bool {
        for filename in ["InterTight", "InstrumentSerif-Italic"] {
            guard let url = resources.url(forResource: filename, withExtension: "ttf") else {
                return false
            }
            // A repeated registration may return false while the font remains available.
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return isAvailable(sansName) && isAvailable(serifName)
    }

    public static func isAvailable(_ name: String) -> Bool {
        let font = CTFontCreateWithName(name as CFString, 14, nil)
        return CTFontCopyPostScriptName(font) as String == name
    }

    private static let resources: Bundle = {
        if let resourceURL = Bundle.main.resourceURL?
            .appendingPathComponent("MilyonusNottaker_DesignSystem.bundle"),
            let packagedBundle = Bundle(url: resourceURL)
        {
            return packagedBundle
        }
        return Bundle.module
    }()
}
