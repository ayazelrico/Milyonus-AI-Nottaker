import DesignSystem
import Shared
import SwiftUI

struct LiveMeetingView: View {
    let preferences: AppPreferences
    let coordinator: LiveMeetingCoordinator

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

                    if coordinator.segments.isEmpty {
                        Text(verbatim: unavailableMessage)
                            .foregroundStyle(DesignTokens.Palette.secondary)
                    } else {
                        transcript
                    }
                }
            }
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
