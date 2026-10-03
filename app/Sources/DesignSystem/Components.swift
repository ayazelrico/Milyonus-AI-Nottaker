import SwiftUI

public enum DSButtonVariant: Sendable {
    case primary
    case secondary
    case quiet
}

public struct DSButton: View {
    private let title: String
    private let symbol: String?
    private let variant: DSButtonVariant
    private let action: () -> Void

    public init(
        _ title: String,
        symbol: String? = nil,
        variant: DSButtonVariant = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.symbol = symbol
        self.variant = variant
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Space.small) {
                if let symbol {
                    Image(systemName: symbol)
                        .accessibilityHidden(true)
                }
                Text(verbatim: title)
            }
        }
        .buttonStyle(BrandedButtonStyle(variant: variant))
    }
}

private struct BrandedButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let variant: DSButtonVariant

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.bodyStrong)
            .foregroundStyle(variant == .primary ? DesignTokens.Palette.canvas : DesignTokens.Palette.foreground)
            .padding(.horizontal, DesignTokens.Space.regular)
            .frame(minHeight: DesignTokens.Layout.controlHeight)
            .background(background, in: Capsule())
            .overlay {
                Capsule().strokeBorder(variant == .primary ? .clear : DesignTokens.Palette.border)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.45)
            .animation(
                reduceMotion ? nil : .easeOut(duration: DesignTokens.Motion.feedbackDuration),
                value: configuration.isPressed
            )
    }

    private var background: Color {
        switch variant {
        case .primary: DesignTokens.Palette.foreground
        case .secondary: DesignTokens.Palette.elevated
        case .quiet: .clear
        }
    }
}

public struct DSTextField: View {
    private let title: String
    @Binding private var text: String

    public init(_ title: String, text: Binding<String>) {
        self.title = title
        _text = text
    }

    public var body: some View {
        TextField(text: $text) {
            Text(verbatim: title)
        }
        .textFieldStyle(.plain)
        .font(DesignTokens.Typography.body)
        .padding(DesignTokens.Space.medium)
        .background(DesignTokens.Palette.canvas, in: RoundedRectangle(cornerRadius: DesignTokens.Shape.control))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Shape.control)
                .strokeBorder(DesignTokens.Palette.border)
        }
        .accessibilityLabel(title)
    }
}

public struct DSCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(DesignTokens.Space.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Palette.surface, in: RoundedRectangle(cornerRadius: DesignTokens.Shape.card))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Shape.card)
                    .strokeBorder(DesignTokens.Palette.border)
            }
    }
}

public enum DSStatusTone: Sendable {
    case neutral
    case sample
    case ready
    case attention
}

public struct DSStatusIndicator: View {
    private let title: String
    private let tone: DSStatusTone

    public init(_ title: String, tone: DSStatusTone = .neutral) {
        self.title = title
        self.tone = tone
    }

    public var body: some View {
        HStack(spacing: DesignTokens.Space.small) {
            Circle().fill(color)
                .frame(width: DesignTokens.Layout.tinyIcon, height: DesignTokens.Layout.tinyIcon)
            Text(verbatim: title).font(DesignTokens.Typography.caption)
        }
        .foregroundStyle(DesignTokens.Palette.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }

    private var color: Color {
        switch tone {
        case .neutral: DesignTokens.Palette.muted
        case .sample: DesignTokens.Palette.cyan
        case .ready: DesignTokens.Palette.success
        case .attention: DesignTokens.Palette.warning
        }
    }
}

public struct DSToggle: View {
    private let title: String
    @Binding private var isOn: Bool

    public init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        _isOn = isOn
    }

    public var body: some View {
        Toggle(isOn: $isOn) { Text(verbatim: title) }
            .toggleStyle(.switch)
            .font(DesignTokens.Typography.body)
            .tint(DesignTokens.Palette.brand)
    }
}
