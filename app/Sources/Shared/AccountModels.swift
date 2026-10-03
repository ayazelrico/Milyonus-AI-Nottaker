import Foundation

public enum SignInProvider: String, Sendable, Codable {
    case apple
    case google
    case email
}

public struct AccountIdentity: Sendable, Equatable {
    public let userID: UUID

    public init(userID: UUID) {
        self.userID = userID
    }
}

/// Session credentials are transient. Implementations persist them only through Keychain.
public struct AuthSession: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let userID: UUID
    public let expiresAt: Date
    private let token: String

    public var description: String {
        "AuthSession(credentials: <redacted>)"
    }

    public var debugDescription: String {
        description
    }

    public init(userID: UUID, accessToken: String, expiresAt: Date) throws {
        guard !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DomainValidationError.emptySessionToken
        }
        self.userID = userID
        token = accessToken
        self.expiresAt = expiresAt
    }

    public func isValid(at date: Date) -> Bool {
        expiresAt > date
    }

    /// Use only for authenticated transport. Never log this value.
    public func authorizationValue() -> String {
        "Bearer \(token)"
    }
}

public struct UsageAllowance: Sendable, Equatable {
    public let usedSeconds: Int
    public let limitSeconds: Int

    public var remainingSeconds: Int {
        max(0, limitSeconds - usedSeconds)
    }

    public var canRecord: Bool {
        remainingSeconds > 0
    }

    public init(usedSeconds: Int, limitSeconds: Int) throws {
        guard usedSeconds >= 0, limitSeconds >= 0 else { throw DomainValidationError.invalidUsage }
        self.usedSeconds = usedSeconds
        self.limitSeconds = limitSeconds
    }
}

public enum CalendarAuthorization: String, Sendable, Codable {
    case notDetermined
    case denied
    case authorized
}

public struct CalendarMeeting: Sendable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let startsAt: Date
    public let endsAt: Date

    public init(id: String, title: String, startsAt: Date, endsAt: Date) throws {
        guard endsAt >= startsAt else { throw DomainValidationError.invalidCalendarRange }
        self.id = id
        self.title = title
        self.startsAt = startsAt
        self.endsAt = endsAt
    }
}
