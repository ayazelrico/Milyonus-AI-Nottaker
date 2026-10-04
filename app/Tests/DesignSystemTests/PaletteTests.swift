import AppKit
import DesignSystem
import Testing

@MainActor
struct PaletteTests {
    @Test func bundledBrandFontsRegisterForTheProcess() {
        #expect(BrandFonts.register())
        #expect(BrandFonts.isAvailable(BrandFonts.sansName))
        #expect(BrandFonts.isAvailable(BrandFonts.serifName))
        #expect(!BrandFonts.isAvailable("Milyonus-MissingFont"))
    }

    @Test func wordmarkIsBundled() {
        #expect(BrandFonts.wordmarkIsAvailable)
    }

    @Test func bodyTextMeetsContrastAgainstCardSurface() throws {
        let background = try #require(NSColor(DesignTokens.Palette.surface).usingColorSpace(.sRGB))
        for color in [DesignTokens.Palette.foreground, DesignTokens.Palette.secondary, DesignTokens.Palette.muted] {
            let foreground = try #require(NSColor(color).usingColorSpace(.sRGB))
            let contrast = (luminance(foreground) + 0.05) / (luminance(background) + 0.05)
            #expect(contrast >= 4.5)
        }
    }

    @Test func brandColorsMatchTheVisualReference() throws {
        let blue = try #require(NSColor(DesignTokens.Palette.brand).usingColorSpace(.sRGB))
        #expect(abs(blue.redComponent - 46.0 / 255) < 0.001)
        #expect(abs(blue.greenComponent - 107.0 / 255) < 0.001)
        #expect(abs(blue.blueComponent - 1) < 0.001)
        let cyan = try #require(NSColor(DesignTokens.Palette.cyan).usingColorSpace(.sRGB))
        #expect(abs(cyan.redComponent - 92.0 / 255) < 0.001)
        #expect(abs(cyan.greenComponent - 200.0 / 255) < 0.001)
        #expect(abs(cyan.blueComponent - 1) < 0.001)
    }

    private func luminance(_ color: NSColor) -> Double {
        let channels = [color.redComponent, color.greenComponent, color.blueComponent].map {
            $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4)
        }
        return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
    }
}
