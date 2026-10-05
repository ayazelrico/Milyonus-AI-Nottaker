import Foundation

public enum STTTokenError: Error, Sendable, Equatable {
    case invalidResponse
    case unauthorized
    case consentRequired
    case entitlementRequired
    case unavailable
}

public struct STTAccessToken: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let expiresIn: TimeInterval
    private let value: String

    public var description: String {
        "STTAccessToken(credentials: <redacted>, expiresIn: \(expiresIn))"
    }

    public var debugDescription: String {
        description
    }

    public init(value: String, expiresIn: TimeInterval) throws {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard value.count <= 8192,
              parts.count == 3,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(Self.isBase64URLCharacter) }),
              expiresIn >= 1,
              expiresIn <= 3600,
              expiresIn.isFinite
        else {
            throw STTTokenError.invalidResponse
        }
        self.value = value
        self.expiresIn = expiresIn
    }

    public func authorizationValue() -> String {
        "Bearer \(value)"
    }

    private static func isBase64URLCharacter(_ character: Character) -> Bool {
        character.isASCII && (character.isLetter || character.isNumber || character == "_" || character == "-")
    }
}

public protocol STTTokenProvider: Sendable {
    func token(consentConfirmed: Bool) async throws -> STTAccessToken
}
