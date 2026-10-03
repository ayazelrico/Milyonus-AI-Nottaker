import SwiftUI

/// Native adaptations of the supplied visual reference with bundled brand fonts and system fallbacks.
public enum DesignTokens {
    public enum Palette {
        public static let brandHex: UInt32 = 0x2E6BFF
        public static let cyanHex: UInt32 = 0x5CC8FF
        public static let canvas = Color.black
        public static let sidebar = color(0x08090C)
        public static let surface = color(0x101216)
        public static let elevated = color(0x181C24)
        public static let brand = color(brandHex)
        public static let cyan = color(cyanHex)
        public static let foreground = Color.white
        public static let secondary = color(0xB4BAC6)
        public static let muted = color(0x929BAB)
        public static let border = Color.white.opacity(0.12)
        public static let activeFill = color(0x111F3E)
        public static let heroTop = color(0x102753)
        public static let heroBottom = color(0x070C17)
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
        public static let display = sans(size: 38)
        public static let displayAccent = serif(size: 40)
        public static let title = sans(size: 28, weight: .medium)
        public static let heading = sans(size: 18, weight: .semibold)
        public static let cardTitle = serif(size: 26)
        public static let body = sans(size: 14)
        public static let bodyStrong = sans(size: 14, weight: .medium)
        public static let caption = sans(size: 12)
        public static let eyebrow = sans(size: 10, weight: .semibold)
        public static let wordmark = sans(size: 21, weight: .semibold)
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
        public static let control: CGFloat = 10
        public static let card: CGFloat = 20
        public static let hero: CGFloat = 24
    }

    public enum Layout {
        public static let sidebar: CGFloat = 224
        public static let windowWidth: CGFloat = 1180
        public static let windowHeight: CGFloat = 790
        public static let minimumWidth: CGFloat = 1000
        public static let minimumHeight: CGFloat = 690
        public static let contentWidth: CGFloat = 1000
        public static let controlHeight: CGFloat = 36
        public static let heroHeight: CGFloat = 252
        public static let heroArtworkWidth: CGFloat = 250
        public static let sectionIcon: CGFloat = 38
        public static let largeIcon: CGFloat = 56
        public static let tinyIcon: CGFloat = 8
        public static let symbol: CGFloat = 16
        public static let wordmarkIcon: CGFloat = 28
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
