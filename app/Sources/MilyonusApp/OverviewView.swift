import DesignSystem
import SwiftUI

struct OverviewView: View {
    let preferences: AppPreferences
    let openSample: () -> Void
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.section) {
            PageHeading(
                eyebrow: preferences.text("A CLEARER HEADSPACE"),
                title: preferences.text("Welcome to your workspace."),
                subtitle: preferences.text("Make room for the conversation. Keep what matters.")
            )
            hero
            HStack(alignment: .top, spacing: DesignTokens.Space.large) {
                VStack(alignment: .leading, spacing: DesignTokens.Space.regular) {
                    SectionHeading(title: preferences.text("A first look"), detail: preferences.text("SAMPLE DATA"))
                    sampleCard
                }
                VStack(alignment: .leading, spacing: DesignTokens.Space.regular) {
                    SectionHeading(title: preferences.text("Before your first meeting"))
                    setupCard
                }
                .frame(width: DesignTokens.Layout.meetingAside)
            }
            HStack(spacing: DesignTokens.Space.small) {
                Image(systemName: "shield.lefthalf.filled")
                    .foregroundStyle(DesignTokens.Palette.brand)
                    .accessibilityHidden(true)
                Text(verbatim: preferences
                    .text("You stay in control. Recording will always require your action and consent."))
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Palette.secondary)
            }
        }
    }

    private var hero: some View {
        HStack(spacing: DesignTokens.Space.large) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.regular) {
                DSStatusIndicator(preferences.text("Meet your meeting companion"), tone: .sample)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: preferences.text("Be here."))
                        .font(DesignTokens.Typography.display)
                    Text(verbatim: preferences.text("Leave with clarity."))
                        .font(DesignTokens.Typography.displayAccent)
                }
                .accessibilityAddTraits(.isHeader)
                Text(verbatim: preferences
                    .text("See how a conversation becomes a useful summary and a clear next step."))
                    .foregroundStyle(DesignTokens.Palette.secondary)
                    .lineSpacing(DesignTokens.Layout.lineHeight)
                    .fixedSize(horizontal: false, vertical: true)
                DSButton(preferences.text("Explore sample meeting"), symbol: "arrow.up.right", action: openSample)
                    .padding(.top, DesignTokens.Space.tiny)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            waveformArtwork
        }
        .padding(DesignTokens.Space.section)
        .frame(minHeight: DesignTokens.Layout.heroHeight)
        .background(DesignTokens.Palette.heroBottom, in: RoundedRectangle(cornerRadius: DesignTokens.Shape.hero))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Shape.hero)
                .strokeBorder(DesignTokens.Palette.border)
        }
    }

    private var waveformArtwork: some View {
        ZStack {
            Circle().stroke(DesignTokens.Palette.brand.opacity(0.18))
                .frame(width: DesignTokens.Layout.heroArtworkWidth, height: DesignTokens.Layout.heroArtworkWidth)
            Circle().stroke(DesignTokens.Palette.brand.opacity(0.2))
                .frame(width: DesignTokens.Layout.glyphRing, height: DesignTokens.Layout.glyphRing)
            HStack(spacing: DesignTokens.Layout.waveformGap) {
                ForEach(Array(DesignTokens.Layout.waveformHeights.enumerated()), id: \.offset) { index, height in
                    Capsule()
                        .fill(index.isMultiple(of: 3) ? DesignTokens.Palette.foreground : DesignTokens.Palette.brand)
                        .frame(width: DesignTokens.Layout.waveformBar, height: height)
                }
            }
        }
        .frame(width: DesignTokens.Layout.heroArtworkWidth)
        .accessibilityHidden(true)
    }

    private var sampleCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.regular) {
                HStack {
                    Image(systemName: "text.bubble")
                        .foregroundStyle(DesignTokens.Palette.brand)
                        .font(DesignTokens.Typography.heading)
                        .accessibilityHidden(true)
                    Spacer()
                    DSStatusIndicator(preferences.text("Sample meeting"), tone: .sample)
                }
                Text(verbatim: preferences.text("Product discovery"))
                    .font(DesignTokens.Typography.cardTitle)
                Text(verbatim: preferences.text("A fictional team explores a simpler way to follow up after meetings."))
                    .foregroundStyle(DesignTokens.Palette.secondary)
                    .lineSpacing(DesignTokens.Layout.lineHeight)
                HStack {
                    Label(preferences.text("Summary + transcript"), systemImage: "doc.text")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Palette.muted)
                    Spacer()
                    DSButton(preferences.text("Open"), symbol: "arrow.right", variant: .quiet, action: openSample)
                }
            }
        }
    }

    private var setupCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.large) {
                setupRow("person.crop.circle", title: "Account", status: "Not connected")
                setupRow("mic", title: "Audio permissions", status: "Not requested")
                setupRow("calendar", title: "Calendar", status: "Not connected")
                DSButton(
                    preferences.text("View setup"),
                    symbol: "arrow.right",
                    variant: .secondary,
                    action: openSettings
                )
            }
        }
    }

    private func setupRow(_ symbol: String, title: String, status: String) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Space.medium) {
            Image(systemName: symbol)
                .foregroundStyle(DesignTokens.Palette.muted)
                .frame(width: DesignTokens.Layout.symbol)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignTokens.Space.tiny) {
                Text(verbatim: preferences.text(title)).font(DesignTokens.Typography.bodyStrong)
                Text(verbatim: preferences.text(status))
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Palette.muted)
            }
        }
    }
}

struct PageHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.medium) {
            Text(verbatim: eyebrow)
                .font(DesignTokens.Typography.eyebrow)
                .tracking(DesignTokens.Layout.letterSpacing)
                .foregroundStyle(DesignTokens.Palette.muted)
            Text(verbatim: title)
                .font(DesignTokens.Typography.title)
                .foregroundStyle(DesignTokens.Palette.foreground)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: subtitle)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SectionHeading: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack {
            Text(verbatim: title)
                .font(DesignTokens.Typography.bodyStrong)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: DesignTokens.Space.small)
            if let detail {
                Text(verbatim: detail)
                    .font(DesignTokens.Typography.eyebrow)
                    .tracking(DesignTokens.Layout.letterSpacing)
                    .foregroundStyle(DesignTokens.Palette.muted)
            }
        }
    }
}
