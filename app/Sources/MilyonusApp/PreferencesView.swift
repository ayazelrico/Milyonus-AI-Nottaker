import DesignSystem
import Shared
import SwiftUI

struct PreferencesView: View {
    @Bindable var preferences: AppPreferences
    @Bindable var authentication: AuthenticationCoordinator
    @Bindable var permissions: PermissionCoordinator

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
                AccountSettingsView(preferences: preferences, authentication: authentication)
            }
            DSCard {
                PermissionSettingsView(preferences: preferences, permissions: permissions)
            }
            DSCard {
                VStack(alignment: .leading, spacing: DesignTokens.Space.large) {
                    SectionHeading(title: preferences.text("Connection status"))
                    connectionRow(
                        "Account",
                        value: authentication.isSignedIn ? "Connected" : "Not connected",
                        symbol: "person.crop.circle"
                    )
                    connectionRow(
                        "Meeting services",
                        value: permissions.snapshot.microphone == .granted
                            && permissions.snapshot.systemAudio == .granted ? "Connected" : "Not configured",
                        symbol: "waveform"
                    )
                    connectionRow("Calendar", value: "Not connected", symbol: "calendar")
                    Text(verbatim: preferences
                        .text(
                            "Calendar connection and recording will be available in a future build."
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
                            "Permission prompts appear only after you choose Request. Audio capture remains off."
                        ))
                        .foregroundStyle(DesignTokens.Palette.secondary)
                        .lineSpacing(DesignTokens.Layout.lineHeight)
                    Text(verbatim: preferences
                        .text(
                            "Meeting consent is required separately before every recording."
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

private struct PermissionSettingsView: View {
    let preferences: AppPreferences
    @Bindable var permissions: PermissionCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.regular) {
            SectionHeading(title: preferences.text("Permissions"))
            permissionRow(.microphone, title: "Microphone", symbol: "mic")
            permissionRow(.systemAudio, title: "System audio", symbol: "rectangle.on.rectangle")
            permissionRow(.notifications, title: "Notifications", symbol: "bell")
            Text(verbatim: preferences
                .text(
                    "Permissions enable app features. Meeting consent is reviewed separately before every recording."
                ))
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Palette.secondary)
                .lineSpacing(DesignTokens.Layout.lineHeight)
            if let errorKey = permissions.errorKey {
                Label(preferences.text(errorKey), systemImage: "exclamationmark.triangle.fill")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Palette.warning)
            }
        }
    }

    private func permissionRow(_ permission: AppPermission, title: String, symbol: String) -> some View {
        let status = permissions.snapshot[permission]
        return HStack(spacing: DesignTokens.Space.medium) {
            Image(systemName: symbol)
                .foregroundStyle(DesignTokens.Palette.muted)
                .frame(width: DesignTokens.Layout.symbol)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignTokens.Space.tiny) {
                Text(verbatim: preferences.text(title))
                Text(verbatim: preferences.text(statusKey(status)))
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(status == .granted ? DesignTokens.Palette.success : DesignTokens.Palette.muted)
            }
            Spacer()
            action(permission, status: status)
        }
    }

    @ViewBuilder
    private func action(_ permission: AppPermission, status: AppPermissionStatus) -> some View {
        if permissions.pendingPermission == permission {
            ProgressView().controlSize(.small)
        } else {
            switch status {
            case .notDetermined:
                DSButton(preferences.text("Request"), variant: .secondary) {
                    Task { await permissions.request(permission) }
                }
            case .denied:
                DSButton(preferences.text("Open System Settings"), variant: .secondary) {
                    Task { await permissions.openSystemSettings(for: permission) }
                }
            case .restartRequired:
                DSButton(preferences.text("Restart Milyonus"), variant: .secondary) {
                    Task { await permissions.restartApplication() }
                }
            case .granted:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DesignTokens.Palette.success)
                    .accessibilityLabel(preferences.text("Granted"))
            }
        }
    }

    private func statusKey(_ status: AppPermissionStatus) -> String {
        switch status {
        case .notDetermined: "Not requested"
        case .granted: "Granted"
        case .denied: "Denied"
        case .restartRequired: "Restart required"
        }
    }
}

private struct AccountSettingsView: View {
    let preferences: AppPreferences
    @Bindable var authentication: AuthenticationCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.regular) {
            SectionHeading(title: preferences.text("Account"))
            switch authentication.state {
            case .notConfigured:
                status(
                    "person.crop.circle.badge.exclamationmark",
                    "Account sign-in needs the Supabase runtime configuration."
                )
            case let .signedIn(userID):
                status("checkmark.circle.fill", "Signed in securely on this Mac.", tone: DesignTokens.Palette.success)
                Text(verbatim: preferences.text("Account ID") + ": " + userID.uuidString.lowercased())
                    .font(DesignTokens.Typography.monospaced)
                    .foregroundStyle(DesignTokens.Palette.muted)
                    .textSelection(.enabled)
                DSButton(preferences.text("Sign out"), variant: .secondary) {
                    Task { await authentication.signOut() }
                }
            case .checkEmail:
                status("envelope.badge", "Check your email and open the secure sign-in link on this Mac.")
                DSButton(preferences.text("Send another link"), variant: .secondary) {
                    Task { await authentication.requestMagicLink() }
                }
            case .sendingMagicLink, .signingIn:
                HStack(spacing: DesignTokens.Space.medium) {
                    ProgressView().controlSize(.small)
                    Text(verbatim: preferences.text("Signing in securely..."))
                        .foregroundStyle(DesignTokens.Palette.secondary)
                }
            case .signedOut:
                DSTextField(preferences.text("Email address"), text: $authentication.email)
                    .onSubmit { Task { await authentication.requestMagicLink() } }
                HStack(spacing: DesignTokens.Space.medium) {
                    DSButton(preferences.text("Email me a sign-in link"), symbol: "envelope") {
                        Task { await authentication.requestMagicLink() }
                    }
                    .disabled(authentication.isBusy)
                    DSButton(preferences.text("Apple"), symbol: "apple.logo", variant: .secondary) {
                        Task { await authentication.signIn(using: .apple) }
                    }
                    .disabled(authentication.isBusy)
                    DSButton(preferences.text("Google"), variant: .secondary) {
                        Task { await authentication.signIn(using: .google) }
                    }
                    .disabled(authentication.isBusy)
                }
                Text(verbatim: preferences
                    .text("Magic Link uses PKCE. Session credentials are stored only in macOS Keychain."))
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Palette.secondary)
            }

            if let errorKey = authentication.errorKey {
                Label(preferences.text(errorKey), systemImage: "exclamationmark.triangle.fill")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Palette.warning)
            }
        }
    }

    private func status(_ symbol: String, _ key: String, tone: Color = DesignTokens.Palette.cyan) -> some View {
        Label(preferences.text(key), systemImage: symbol)
            .foregroundStyle(tone)
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
