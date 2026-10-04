import SwiftUI

/// Native adaptations of the supplied visual reference with bundled brand fonts and system fallbacks.
public enum DesignTokens {
    public enum Palette {
        public static let brandHex: UInt32 = 0x2E6BFF
        public static let cyanHex: UInt32 = 0x5CC8FF
        public static let canvas = Color.black
        public static let sidebar = Color.black
        public static let surface = color(0x181818)
        public static let elevated = color(0x202020)
        public static let brand = color(brandHex)
        public static let cyan = color(cyanHex)
        public static let foreground = color(0xF4F4F2)
        public static let secondary = color(0xA8A8A5)
        public static let muted = color(0x91918E)
        public static let border = color(0x353535)
        public static let divider = color(0x242424)
        public static let activeFill = color(0x071124)
        public static let heroTop = color(0x181818)
        public static let heroBottom = color(0x131313)
        public static let success = color(0x22C55E)
        public static let warning = color(0xF5A524)

        public static func color(_ hex: UInt32) -> Color {
            Color(
                .sRGB,
                red: Double((hex >> 16) & 0xFF) / 255,
                green: Double((hex >> 8) & 0xFF) / 255,
                blue: Double(hex & 0xFF) / 255,
                opacity: 1
            )
        }
    }

    public enum Typography {
        public static let display = sans(size: 40, weight: .medium)
        public static let displayAccent = serif(size: 42)
        public static let title = sans(size: 32, weight: .medium)
        public static let heading = sans(size: 17, weight: .medium)
        public static let cardTitle = serif(size: 28)
        public static let body = sans(size: 15)
        public static let bodyStrong = sans(size: 15, weight: .medium)
        public static let caption = sans(size: 13)
        public static let eyebrow = sans(size: 11, weight: .medium)
        public static let wordmark = serif(size: 30)
        public static let monospaced = Font.system(size: 12, design: .monospaced)
        public static let navigationSymbol = Font.system(size: 16)
        public static let brandSymbol = Font.system(size: 28, weight: .medium)
        public static let illustrationSymbol = Font.system(size: 56, weight: .ultraLight)

        private static func sans(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            BrandFonts.isAvailable(BrandFonts.sansName)
                ? Font.custom(BrandFonts.sansName, size: size).weight(weight)
                : Font.system(size: size, weight: weight)
        }

        private static func serif(size: CGFloat) -> Font {
            BrandFonts.isAvailable(BrandFonts.serifName)
                ? Font.custom(BrandFonts.serifName, size: size)
                : Font.system(size: size, design: .serif).italic()
        }
    }

    public enum Space {
        public static let hairline: CGFloat = 1
        public static let tiny: CGFloat = 4
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let regular: CGFloat = 16
        public static let large: CGFloat = 24
        public static let section: CGFloat = 32
        public static let page: CGFloat = 40
        public static let generous: CGFloat = 48
    }

    public enum Shape {
        public static let control: CGFloat = 12
        public static let card: CGFloat = 18
        public static let hero: CGFloat = 18
    }

    public enum Layout {
        public static let sidebar: CGFloat = 236
        public static let windowWidth: CGFloat = 1280
        public static let windowHeight: CGFloat = 820
        public static let minimumWidth: CGFloat = 1040
        public static let minimumHeight: CGFloat = 700
        public static let contentWidth: CGFloat = 1080
        public static let controlHeight: CGFloat = 38
        public static let heroHeight: CGFloat = 252
        public static let heroArtworkWidth: CGFloat = 250
        public static let sectionIcon: CGFloat = 38
        public static let largeIcon: CGFloat = 56
        public static let tinyIcon: CGFloat = 8
        public static let symbol: CGFloat = 16
        public static let wordmarkIcon: CGFloat = 28
        public static let wordmarkWidth: CGFloat = 166
        public static let wordmarkHeight: CGFloat = 44
        public static let transcriptTime: CGFloat = 56
        public static let meetingAside: CGFloat = 228
        public static let settingsWidth: CGFloat = 600
        public static let galleryWidth: CGFloat = 840
        public static let galleryHeight: CGFloat = 800
        public static let galleryMinimumWidth: CGFloat = 700
        public static let galleryMinimumHeight: CGFloat = 600
        public static let emptyHeight: CGFloat = 240
        public static let lineHeight: CGFloat = 5
        public static let letterSpacing: CGFloat = 1.8
        public static let waveformHeights: [CGFloat] = [12, 22, 15, 36, 56, 29, 73, 47, 90, 60, 34, 66, 40, 20, 31]
        public static let waveformBar: CGFloat = 4
        public static let waveformGap: CGFloat = 6
        public static let glyphRing: CGFloat = 152
    }

    public enum Motion {
        public static let feedbackDuration: Double = 0.14
    }
}
