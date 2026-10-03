import DesignSystem
import Shared
import SwiftUI

struct PreferencesView: View {
    @Bindable var preferences: AppPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.large) {
            PageHeading(
                eyebrow: preferences.text("MAKE IT YOURS"),
                title: preferences.text("Settings"),
                subtitle: preferences.text("A few preferences. A clear view of what is connected.")
            )
            DSCard {
                VStack(alignment: .leading, spacing: DesignTokens.Space.regular) {
                    SectionHeading(title: preferences.text("Language"))
                    Picker(selection: $preferences.language) {
                        Text("English").tag(AppLanguage.english)
                        Text("Türkçe").tag(AppLanguage.turkish)
                    } label: {
                        Text(verbatim: preferences.text("App language"))
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(preferences.text("App language"))
                    Text(verbatim: preferences
                        .text("English is the default. Your choice is saved on this Mac and applies immediately."))
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Palette.secondary)
                }
            }
            DSCard {
                VStack(alignment: .leading, spacing: DesignTokens.Space.large) {
                    SectionHeading(title: preferences.text("Connection status"))
                    connectionRow("Account", value: "Not connected", symbol: "person.crop.circle")
                    connectionRow("Meeting services", value: "Not configured", symbol: "waveform")
                    connectionRow("Calendar", value: "Not connected", symbol: "calendar")
                    Text(verbatim: preferences
                        .text(
                            "Account sign-in, calendar connection, and recording will be available in a future build."
                        ))
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Palette.secondary)
                        .lineSpacing(DesignTokens.Layout.lineHeight)
                }
            }
            DSCard {
                VStack(alignment: .leading, spacing: DesignTokens.Space.regular) {
                    Label(preferences.text("Privacy comes first"), systemImage: "lock.shield")
                        .font(DesignTokens.Typography.heading)
                        .foregroundStyle(DesignTokens.Palette.foreground)
                    Text(verbatim: preferences
                        .text(
                            "This preview does not capture your microphone or system audio, request recording permissions, "
                                + "or send meeting data to a server."
                        ))
                        .foregroundStyle(DesignTokens.Palette.secondary)
                        .lineSpacing(DesignTokens.Layout.lineHeight)
                    Text(verbatim: preferences
                        .text(
                            "Before recording becomes available, you will be able to review consent and permissions."
                        ))
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Palette.muted)
                }
            }
        }
        .font(DesignTokens.Typography.body)
        .foregroundStyle(DesignTokens.Palette.foreground)
    }

    private func connectionRow(_ title: String, value: String, symbol: String) -> some View {
        HStack(spacing: DesignTokens.Space.medium) {
            Image(systemName: symbol)
                .foregroundStyle(DesignTokens.Palette.muted)
                .frame(width: DesignTokens.Layout.symbol)
                .accessibilityHidden(true)
            Text(verbatim: preferences.text(title))
            Spacer()
            DSStatusIndicator(preferences.text(value))
        }
    }
}

struct KnowledgeView: View {
    let preferences: AppPreferences
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.section) {
            PageHeading(
                eyebrow: preferences.text("CONTEXT THAT COUNTS"),
                title: preferences.text("Your knowledge, close at hand."),
                subtitle: preferences.text("A place for the documents that make your conversations more useful.")
            )
            DSCard {
                VStack(alignment: .center, spacing: DesignTokens.Space.large) {
                    Image(systemName: "books.vertical")
                        .font(DesignTokens.Typography.illustrationSymbol)
                        .foregroundStyle(DesignTokens.Palette.cyan)
                        .accessibilityHidden(true)
                    VStack(spacing: DesignTokens.Space.medium) {
                        Text(verbatim: preferences.text("A fresh page."))
                            .font(DesignTokens.Typography.cardTitle)
                        Text(verbatim: preferences
                            .text(
                                "No documents have been added. Document upload and grounded suggestions are not available in this preview."
                            ))
                            .foregroundStyle(DesignTokens.Palette.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(DesignTokens.Layout.lineHeight)
                    }
                    HStack(spacing: DesignTokens.Space.medium) {
                        DSButton(preferences.text("Add documents"), symbol: "plus", action: {})
                            .disabled(true)
                            .help(preferences
                                .text("Document upload requires a connected account and meeting services."))
                        DSButton(preferences.text("View setup"), variant: .secondary, action: openSettings)
                    }
                }
                .padding(DesignTokens.Space.section)
                .frame(maxWidth: .infinity, minHeight: DesignTokens.Layout.emptyHeight)
            }
            HStack(alignment: .top, spacing: DesignTokens.Space.medium) {
                Image(systemName: "lock.shield").foregroundStyle(DesignTokens.Palette.cyan)
                Text(verbatim: preferences
                    .text(
                        "Your documents will only be used after you choose to add them. "
                            + "You will be able to review sources for grounded suggestions."
                    ))
                    .foregroundStyle(DesignTokens.Palette.secondary)
                    .lineSpacing(DesignTokens.Layout.lineHeight)
            }
        }
    }
}
