#if DEBUG
    import DesignSystem
    import SwiftUI

    struct ComponentGallery: View {
        let preferences: AppPreferences
        @State private var fieldText = ""
        @State private var toggleValue = false
        @State private var buttonPresses = 0

        var body: some View {
            VStack(alignment: .leading, spacing: DesignTokens.Space.large) {
                PageHeading(
                    eyebrow: preferences.text("DESIGN SYSTEM"),
                    title: preferences.text("Component gallery"),
                    subtitle: preferences
                        .text("Five native building blocks. Gallery controls affect this preview only.")
                )
                DSCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Space.regular) {
                        SectionHeading(title: preferences.text("Buttons"))
                        HStack(spacing: DesignTokens.Space.medium) {
                            DSButton(preferences.text("Primary"), symbol: "plus") { buttonPresses += 1 }
                            DSButton(preferences.text("Secondary"), variant: .secondary) { buttonPresses += 1 }
                            DSButton(preferences.text("Quiet"), variant: .quiet) { buttonPresses += 1 }
                            DSButton(preferences.text("Disabled"), action: {}).disabled(true)
                        }
                        HStack {
                            Text(verbatim: preferences.text("Button presses"))
                            Text(buttonPresses, format: .number)
                        }
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Palette.secondary)
                    }
                }
                DSCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Space.regular) {
                        SectionHeading(title: preferences.text("Text field"))
                        DSTextField(preferences.text("Try typing here"), text: $fieldText)
                        SectionHeading(title: preferences.text("Toggle"))
                        DSToggle(preferences.text("Preview preference"), isOn: $toggleValue)
                    }
                }
                DSCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Space.regular) {
                        SectionHeading(title: preferences.text("Status indicators"))
                        HStack(spacing: DesignTokens.Space.large) {
                            DSStatusIndicator(preferences.text("Neutral"))
                            DSStatusIndicator(preferences.text("Sample"), tone: .sample)
                            DSStatusIndicator(preferences.text("Ready example"), tone: .ready)
                            DSStatusIndicator(preferences.text("Attention example"), tone: .attention)
                        }
                        Text(verbatim: preferences.text("Status is always described in text, as well as color."))
                            .foregroundStyle(DesignTokens.Palette.secondary)
                    }
                }
                DSCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Space.regular) {
                        SectionHeading(title: preferences.text("Card"))
                        Text(verbatim: preferences.text("A little space to think."))
                            .font(DesignTokens.Typography.cardTitle)
                        Text(verbatim: preferences
                            .text(
                                "Inter Tight and Instrument Serif are bundled under the SIL Open Font License. System font fallbacks remain available."
                            ))
                            .foregroundStyle(DesignTokens.Palette.secondary)
                        Text(verbatim: preferences
                            .text(
                                "Controls respect Reduce Motion. Surfaces remain opaque and readable with Reduce Transparency."
                            ))
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Palette.muted)
                    }
                }
            }
        }
    }
#endif
