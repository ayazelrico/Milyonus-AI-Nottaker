public enum TranscriptionError: Error, Sendable, Equatable {
    case alreadyTranscribingChannel
    case channelChanged
    case connectionClosed
    case invalidProviderMessage
    case reconnectLimitReached
    case timestampRegression
}
