import Foundation
import Shared

public enum ReplayFixtureLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case turkish = "tr"
}

public struct ReplayFixture: Sendable, Equatable, Hashable, Identifiable {
    public let language: ReplayFixtureLanguage
    public let channel: AudioChannel

    public var id: String {
        "\(language.rawValue)-\(channel.rawValue)"
    }

    var resourceName: String {
        switch (language, channel) {
        case (.english, .microphone): "en-microphone"
        case (.english, .system): "en-system"
        case (.turkish, .microphone): "tr-microphone"
        case (.turkish, .system): "tr-system"
        }
    }

    public init(language: ReplayFixtureLanguage, channel: AudioChannel) {
        self.language = language
        self.channel = channel
    }
}
