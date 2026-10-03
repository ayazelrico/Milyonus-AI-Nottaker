import Foundation

public enum GenerationTask: String, Sendable, Codable {
    case triggerClassification
    case liveInsight
    case meetingSummary
    case emailDraft
    case preCallBrief
}

/// Input is untrusted data. Server adapters select versioned prompts and models by task.
public struct GenerationRequest: Sendable, Equatable {
    public let meetingID: UUID
    public let task: GenerationTask
    public let input: String
    public let language: AppLanguage

    public init(meetingID: UUID, task: GenerationTask, input: String, language: AppLanguage = .defaultLanguage) {
        self.meetingID = meetingID
        self.task = task
        self.input = input
        self.language = language
    }
}

public struct SourceReference: Sendable, Identifiable, Equatable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public enum GenerationEvent: Sendable, Equatable {
    case textDelta(String)
    case sources([SourceReference])
    case completed
}

public struct EmbeddingVector: Sendable, Equatable {
    public let values: [Float]

    public init(values: [Float]) throws {
        guard !values.isEmpty else { throw DomainValidationError.emptyEmbedding }
        guard values.allSatisfy(\.isFinite) else { throw DomainValidationError.nonFiniteEmbedding }
        self.values = values
    }
}
