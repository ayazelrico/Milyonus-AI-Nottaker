import DesignSystem
import Shared
import SwiftUI

struct LiveMeetingView: View {
    let preferences: AppPreferences
    @Bindable var coordinator: LiveMeetingCoordinator
    @State private var isShowingConsent = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.section) {
            PageHeading(
                eyebrow: preferences.text("LIVE MEETING"),
                title: preferences.text("Live transcript"),
                subtitle: preferences.text("Follow the conversation as it happens.")
            )

            DSCard {
                VStack(alignment: .leading, spacing: DesignTokens.Space.large) {
                    HStack {
                        DSStatusIndicator(statusTitle, tone: statusTone)
                        Spacer()
                        if coordinator.isListening {
                            DSButton(
                                preferences.text("Stop recording"),
                                symbol: "stop.fill",
                                variant: .secondary,
                                action: coordinator.stop
                            )
                        } else {
                            DSButton(
                                preferences.text("Start recording"),
                                symbol: "mic",
                                action: { coordinator.start() }
                            )
                            .disabled(!coordinator.canStart)
                        }
                    }

                    if !coordinator.consentConfirmed {
                        DSButton(
                            preferences.text("Review consent"),
                            symbol: "checkmark.shield",
                            variant: .quiet,
                            action: { isShowingConsent = true }
                        )
                    }

                    if coordinator.segments.isEmpty {
                        Text(verbatim: unavailableMessage)
                            .foregroundStyle(DesignTokens.Palette.secondary)
                    } else {
                        transcript
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingConsent) {
            ConsentSheet(preferences: preferences, coordinator: coordinator)
        }
    }

    private var transcript: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.medium) {
            ForEach(coordinator.segments) { segment in
                HStack(alignment: .top, spacing: DesignTokens.Space.regular) {
                    Text(timecode(for: segment))
                        .font(DesignTokens.Typography.monospaced)
                        .foregroundStyle(DesignTokens.Palette.muted)
                        .frame(width: DesignTokens.Layout.transcriptTime, alignment: .leading)
                    Text(verbatim: segment.text)
                        .foregroundStyle(segment.isFinal ? DesignTokens.Palette.foreground : DesignTokens.Palette
                            .secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var statusTitle: String {
        switch coordinator.state {
        case .listening: preferences.text("Listening")
        case .starting: preferences.text("Starting recording")
        case .stopping: preferences.text("Stopping recording")
        case .failed: preferences.text("Recording unavailable")
        case .idle: preferences.text("Ready to record")
        }
    }

    private var statusTone: DSStatusTone {
        switch coordinator.state {
        case .listening: .ready
        case .starting, .stopping, .failed: .attention
        case .idle: .neutral
        }
    }

    private var unavailableMessage: String {
        switch coordinator.unavailableReason {
        case .consent: preferences.text("Meeting consent is required separately before every recording.")
        case .services, .none: preferences.text("Recording is not available in this preview.")
        }
    }

    private func timecode(for segment: TranscriptSegment) -> String {
        let totalSeconds = segment.startMilliseconds / 1000
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

private struct ConsentSheet: View {
    let preferences: AppPreferences
    @Bindable var coordinator: LiveMeetingCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var accepted = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.large) {
            PageHeading(
                eyebrow: preferences.text("PRIVACY"),
                title: preferences.text("Meeting consent"),
                subtitle: preferences
                    .text("You stay in control. Recording will always require your action and consent.")
            )
            Text(verbatim: preferences
                .text("Before recording becomes available, you will be able to review consent and permissions."))
                .foregroundStyle(DesignTokens.Palette.secondary)
            Toggle(isOn: $accepted) {
                Text(verbatim: preferences
                    .text("I understand that microphone and system audio may be captured and sent for transcription."))
            }
            .toggleStyle(.switch)
            HStack {
                Spacer()
                DSButton(preferences.text("Cancel"), variant: .quiet, action: { dismiss() })
                DSButton(preferences.text("Continue"), symbol: "checkmark", action: {
                    coordinator.consentConfirmed = accepted
                    dismiss()
                })
                .disabled(!accepted)
            }
        }
        .padding(DesignTokens.Space.section)
        .frame(width: 560)
        .foregroundStyle(DesignTokens.Palette.foreground)
        .background(DesignTokens.Palette.canvas)
        .onAppear { accepted = coordinator.consentConfirmed }
    }
}
