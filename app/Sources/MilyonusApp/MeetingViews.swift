import AppKit
import DesignSystem
import SwiftUI

struct MeetingLibraryView: View {
    let preferences: AppPreferences
    let openSample: () -> Void
    @State private var search = ""

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.section) {
            PageHeading(
                eyebrow: preferences.text("YOUR CONVERSATIONS"),
                title: preferences.text("Meetings, with a little more clarity."),
                subtitle: preferences.text("Your real meetings will appear here once recording is available.")
            )
            HStack(spacing: DesignTokens.Space.regular) {
                DSTextField(preferences.text("Search sample meetings"), text: $search)
                DSButton(preferences.text("Start recording"), symbol: "mic", action: {})
                    .disabled(true)
                    .help(preferences.text("Recording is not available in this preview."))
            }
            DSStatusIndicator(preferences.text("Recording is not available in this preview."), tone: .neutral)
            if matchesSample {
                DSCard {
                    HStack(alignment: .center, spacing: DesignTokens.Space.large) {
                        Image(systemName: "text.bubble")
                            .font(DesignTokens.Typography.brandSymbol)
                            .foregroundStyle(DesignTokens.Palette.cyan)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: DesignTokens.Space.medium) {
                            DSStatusIndicator(preferences.text("Sample meeting"), tone: .sample)
                            Text(verbatim: preferences.text("Product discovery"))
                                .font(DesignTokens.Typography.heading)
                            Text(verbatim: preferences
                                .text("Fictional conversation. Explore the summary, action items, and transcript."))
                                .foregroundStyle(DesignTokens.Palette.secondary)
                        }
                        Spacer(minLength: 0)
                        DSButton(
                            preferences.text("Open sample"),
                            symbol: "arrow.right",
                            variant: .secondary,
                            action: openSample
                        )
                    }
                }
            } else {
                DSCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Space.regular) {
                        Text(verbatim: preferences.text("No matching sample meetings"))
                            .font(DesignTokens.Typography.heading)
                        Text(verbatim: preferences.text("Try searching for Product discovery."))
                            .foregroundStyle(DesignTokens.Palette.secondary)
                        DSButton(preferences.text("Clear search"), variant: .secondary) { search = "" }
                    }
                }
            }
        }
    }

    private var matchesSample: Bool {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty || preferences.text("Product discovery").localizedCaseInsensitiveContains(query)
    }
}

struct SampleMeetingView: View {
    let preferences: AppPreferences
    let back: () -> Void
    @State private var selectedTab = "Summary"
    @State private var hasCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.large) {
            DSButton(preferences.text("All meetings"), symbol: "arrow.left", variant: .quiet, action: back)
            PageHeading(
                eyebrow: preferences.text("SAMPLE MEETING"),
                title: preferences.text("Product discovery"),
                subtitle: preferences
                    .text("A fictional conversation, written to help you explore. No audio was recorded or processed.")
            )
            HStack(spacing: DesignTokens.Space.medium) {
                ForEach(["Summary", "Transcript"], id: \.self) { tab in
                    DSButton(
                        preferences.text(tab), symbol: selectedTab == tab ? "checkmark" : nil,
                        variant: selectedTab == tab ? .primary : .quiet
                    ) {
                        selectedTab = tab
                    }
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                }
                Spacer()
                if selectedTab == "Summary" {
                    DSButton(
                        preferences.text(hasCopied ? "Copied" : "Copy sample summary"),
                        symbol: hasCopied ? "checkmark" : "doc.on.doc", variant: .secondary,
                        action: copySummary
                    )
                }
            }
            if selectedTab == "Summary" {
                summary
            } else {
                transcript
            }
        }
        .onChange(of: preferences.language) { hasCopied = false }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.large) {
            DSCard {
                VStack(alignment: .leading, spacing: DesignTokens.Space.regular) {
                    Label(preferences.text("The conversation, distilled"), systemImage: "sparkles")
                        .font(DesignTokens.Typography.cardTitle)
                    Text(verbatim: preferences.text(SampleContent.summary))
                        .foregroundStyle(DesignTokens.Palette.secondary)
                        .lineSpacing(DesignTokens.Layout.lineHeight)
                        .textSelection(.enabled)
                }
            }
            HStack(alignment: .top, spacing: DesignTokens.Space.large) {
                DSCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Space.large) {
                        SectionHeading(title: preferences.text("Decisions"))
                        ForEach(SampleContent.decisions, id: \.self) { decision in
                            detailRow(symbol: "checkmark.circle", text: decision)
                        }
                    }
                }
                DSCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Space.large) {
                        SectionHeading(title: preferences.text("Next steps"))
                        ForEach(SampleContent.actions, id: \.self) { action in
                            detailRow(symbol: "arrow.right.circle", text: action)
                        }
                    }
                }
            }
            Text(verbatim: preferences.text("This summary is a hand-written example, not an AI-generated result."))
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Palette.muted)
        }
    }

    private var transcript: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DesignTokens.Space.large) {
                SectionHeading(title: preferences.text("Sample transcript"), detail: preferences.text("FICTIONAL"))
                ForEach(SampleContent.excerpts) { excerpt in
                    HStack(alignment: .top, spacing: DesignTokens.Space.regular) {
                        Text(excerpt.time)
                            .font(DesignTokens.Typography.monospaced)
                            .foregroundStyle(DesignTokens.Palette.muted)
                            .frame(width: DesignTokens.Layout.transcriptTime, alignment: .leading)
                        VStack(alignment: .leading, spacing: DesignTokens.Space.small) {
                            Text(verbatim: preferences.text(excerpt.speaker))
                                .font(DesignTokens.Typography.bodyStrong)
                                .foregroundStyle(DesignTokens.Palette.cyan)
                            Text(verbatim: preferences.text(excerpt.text))
                                .foregroundStyle(DesignTokens.Palette.secondary)
                                .lineSpacing(DesignTokens.Layout.lineHeight)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }

    private func detailRow(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Space.medium) {
            Image(systemName: symbol)
                .foregroundStyle(DesignTokens.Palette.cyan)
                .accessibilityHidden(true)
            Text(verbatim: preferences.text(text))
                .foregroundStyle(DesignTokens.Palette.secondary)
                .lineSpacing(DesignTokens.Layout.lineHeight)
                .textSelection(.enabled)
        }
    }

    private func copySummary() {
        let sections = [
            preferences.text("SAMPLE MEETING"),
            preferences.text("Product discovery"),
            preferences.text(SampleContent.summary),
            preferences.text("Decisions"),
            SampleContent.decisions.map { "• " + preferences.text($0) }.joined(separator: "\n"),
            preferences.text("Next steps"),
            SampleContent.actions.map { "• " + preferences.text($0) }.joined(separator: "\n"),
            preferences.text("This summary is a hand-written example, not an AI-generated result."),
        ]
        NSPasteboard.general.clearContents()
        hasCopied = NSPasteboard.general.setString(sections.joined(separator: "\n\n"), forType: .string)
    }
}

private enum SampleContent {
    static let summary = "The team wants follow-ups to be easier to find and act on. They agreed to start with a concise meeting summary and clear action owners, then test the flow with a small group before expanding the scope."
    static let decisions = [
        "Keep the first version focused on summaries and action items.",
        "Review the sample flow with three teammates before the next planning session.",
    ]
    static let actions = [
        "Product lead: write a short list of follow-up pain points.",
        "Design lead: sketch a meeting recap with clear action owners.",
    ]
    static let excerpts = [
        Excerpt(
            time: "00:00",
            speaker: "Product lead",
            text: "The conversation itself is useful. The hard part is remembering what we agreed to do afterward."
        ),
        Excerpt(
            time: "00:12",
            speaker: "Design lead",
            text: "Could we start with a short recap, then make each action and its owner easy to scan?"
        ),
        Excerpt(
            time: "00:23",
            speaker: "Product lead",
            text: "Yes. Let's focus on summaries and action items first. I'll collect the follow-up pain points."
        ),
        Excerpt(
            time: "00:35",
            speaker: "Design lead",
            text: "I'll sketch that flow. We can review it with three teammates before the next planning session."
        ),
    ]

    struct Excerpt: Identifiable {
        let time: String
        let speaker: String
        let text: String
        var id: String {
            time
        }
    }
}
