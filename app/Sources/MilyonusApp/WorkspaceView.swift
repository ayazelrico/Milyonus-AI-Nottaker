import DesignSystem
import SwiftUI

enum Destination: String, CaseIterable, Identifiable {
    case workspace = "Workspace"
    case meetings = "Meetings"
    case knowledge = "Knowledge base"
    case settings = "Settings"
    #if DEBUG
        case gallery = "Component gallery"
    #endif

    var id: String {
        rawValue
    }

    var symbol: String {
        switch self {
        case .workspace: "square.grid.2x2"
        case .meetings: "text.bubble"
        case .knowledge: "books.vertical"
        case .settings: "slider.horizontal.3"
        #if DEBUG
            case .gallery: "square.stack.3d.up"
        #endif
        }
    }
}

struct WorkspaceView: View {
    let preferences: AppPreferences
    let authentication: AuthenticationCoordinator
    let permissions: PermissionCoordinator
    @State private var destination = Destination.workspace
    @State private var isShowingSample = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(DesignTokens.Palette.divider).frame(width: DesignTokens.Space.hairline)
            VStack(spacing: 0) {
                toolbar
                Rectangle().fill(DesignTokens.Palette.divider).frame(height: DesignTokens.Space.hairline)
                ScrollView {
                    content
                        .frame(maxWidth: DesignTokens.Layout.contentWidth, alignment: .leading)
                        .padding(DesignTokens.Space.section)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        }
        .font(DesignTokens.Typography.body)
        .foregroundStyle(DesignTokens.Palette.foreground)
        .background(DesignTokens.Palette.canvas)
        .frame(minWidth: DesignTokens.Layout.minimumWidth, minHeight: DesignTokens.Layout.minimumHeight)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.large) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.tiny) {
                MilyonusWordmark()
                Text("AI NOTTAKER")
                    .font(DesignTokens.Typography.eyebrow)
                    .tracking(DesignTokens.Layout.letterSpacing)
                    .foregroundStyle(DesignTokens.Palette.muted)
                    .padding(.leading, DesignTokens.Space.small)
            }
            .padding(.top, DesignTokens.Space.large)
            .padding(.bottom, DesignTokens.Space.medium)

            VStack(alignment: .leading, spacing: DesignTokens.Space.small) {
                eyebrow("YOUR SPACE")
                    .padding(.horizontal, DesignTokens.Space.medium)
                    .padding(.bottom, DesignTokens.Space.small)
                navigationButton(.workspace)
                navigationButton(.meetings)
                navigationButton(.knowledge)
            }

            Spacer()

            VStack(alignment: .leading, spacing: DesignTokens.Space.medium) {
                Image(systemName: "lock.shield")
                    .font(DesignTokens.Typography.heading)
                    .foregroundStyle(DesignTokens.Palette.brand)
                    .accessibilityHidden(true)
                Text(verbatim: preferences.text("Your space. Your words."))
                    .font(DesignTokens.Typography.bodyStrong)
                Text(verbatim: preferences.text("Explore with sample data. Nothing is being recorded or uploaded."))
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Palette.secondary)
                    .lineSpacing(DesignTokens.Layout.lineHeight)
            }
            .padding(DesignTokens.Space.regular)
            .background(DesignTokens.Palette.surface, in: RoundedRectangle(cornerRadius: DesignTokens.Shape.card))

            VStack(spacing: DesignTokens.Space.small) {
                #if DEBUG
                    navigationButton(.gallery)
                #endif
                navigationButton(.settings)
                HStack(spacing: DesignTokens.Space.small) {
                    Image(systemName: "person.crop.circle")
                    Text(verbatim: preferences.text(authentication.isSignedIn ? "Connected" : "Local preview"))
                    Spacer()
                    Text("v0.1").font(DesignTokens.Typography.caption)
                }
                .foregroundStyle(DesignTokens.Palette.muted)
                .padding(DesignTokens.Space.medium)
            }
        }
        .padding(.horizontal, DesignTokens.Space.regular)
        .padding(.bottom, DesignTokens.Space.regular)
        .frame(width: DesignTokens.Layout.sidebar)
        .background(DesignTokens.Palette.sidebar)
    }

    private var toolbar: some View {
        HStack {
            Text(verbatim: preferences.text(destination.rawValue))
                .font(DesignTokens.Typography.bodyStrong)
            if isShowingSample, destination == .meetings {
                Image(systemName: "chevron.right")
                    .foregroundStyle(DesignTokens.Palette.muted)
                Text(verbatim: preferences.text("Product discovery"))
                    .foregroundStyle(DesignTokens.Palette.secondary)
            }
            Spacer()
            DSStatusIndicator(preferences.text("Sample workspace"), tone: .sample)
            Text(preferences.language.rawValue.uppercased())
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Palette.secondary)
                .padding(.leading, DesignTokens.Space.regular)
                .accessibilityLabel(preferences.text("App language"))
                .accessibilityValue(preferences.language.rawValue)
        }
        .padding(.horizontal, DesignTokens.Space.section)
        .padding(.vertical, DesignTokens.Space.large)
    }

    @ViewBuilder private var content: some View {
        switch destination {
        case .workspace:
            OverviewView(preferences: preferences, openSample: openSample, openSettings: { destination = .settings })
        case .meetings:
            if isShowingSample {
                SampleMeetingView(preferences: preferences, back: { isShowingSample = false })
            } else {
                MeetingLibraryView(preferences: preferences, openSample: openSample)
            }
        case .knowledge:
            KnowledgeView(preferences: preferences, openSettings: { destination = .settings })
        case .settings:
            PreferencesView(
                preferences: preferences,
                authentication: authentication,
                permissions: permissions
            )
        #if DEBUG
            case .gallery:
                ComponentGallery(preferences: preferences)
        #endif
        }
    }

    private func navigationButton(_ item: Destination) -> some View {
        Button {
            destination = item
            isShowingSample = false
        } label: {
            HStack(spacing: DesignTokens.Space.medium) {
                Image(systemName: item.symbol)
                    .font(DesignTokens.Typography.navigationSymbol)
                    .frame(width: DesignTokens.Layout.symbol)
                    .accessibilityHidden(true)
                Text(verbatim: preferences.text(item.rawValue))
                Spacer(minLength: 0)
                if destination == item {
                    Image(systemName: "checkmark")
                        .font(DesignTokens.Typography.caption)
                        .accessibilityHidden(true)
                }
            }
            .font(DesignTokens.Typography.bodyStrong)
            .foregroundStyle(destination == item ? DesignTokens.Palette.foreground : DesignTokens.Palette.secondary)
            .padding(DesignTokens.Space.medium)
            .background(
                destination == item ? DesignTokens.Palette.activeFill : .clear,
                in: RoundedRectangle(cornerRadius: DesignTokens.Shape.control)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Shape.control)
                    .strokeBorder(destination == item ? DesignTokens.Palette.brand : .clear)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(destination == item ? .isSelected : [])
    }

    private func eyebrow(_ key: String) -> some View {
        Text(verbatim: preferences.text(key))
            .font(DesignTokens.Typography.eyebrow)
            .tracking(DesignTokens.Layout.letterSpacing)
            .foregroundStyle(DesignTokens.Palette.muted)
    }

    private func openSample() {
        destination = .meetings
        isShowingSample = true
    }
}
