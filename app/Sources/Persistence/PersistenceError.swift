import Foundation

public enum TranscriptPersistenceError: Error, Sendable, Equatable {
    case invalidEncryptionKey
    case encryptionFailed
    case decryptionFailed
    case segmentIdentityChanged
    case finalityRegression
    case invalidBatch
    case invalidResponse
    case unauthorized
    case unavailable
}
