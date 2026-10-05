import Foundation

public enum DeepgramSocketMessage: Sendable, Equatable {
    case data(Data)
    case text(String)
}

public protocol DeepgramSocket: Sendable {
    func send(_ message: DeepgramSocketMessage) async throws
    func receive() async throws -> DeepgramSocketMessage?
    func close() async
}

public protocol DeepgramSocketFactory: Sendable {
    func connect(request: URLRequest) async throws -> any DeepgramSocket
}

public struct URLSessionDeepgramSocketFactory: DeepgramSocketFactory {
    public init() {}

    public func connect(request: URLRequest) async throws -> any DeepgramSocket {
        URLSessionDeepgramSocket(request: request)
    }
}

private actor URLSessionDeepgramSocket: DeepgramSocket {
    private let session: URLSession
    private let task: URLSessionWebSocketTask
    private var closed = false

    init(request: URLRequest) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: configuration)
        self.session = session
        task = session.webSocketTask(with: request)
        task.resume()
    }

    func send(_ message: DeepgramSocketMessage) async throws {
        guard !closed else { throw TranscriptionError.connectionClosed }
        switch message {
        case let .data(data):
            try await task.send(.data(data))
        case let .text(text):
            try await task.send(.string(text))
        }
    }

    func receive() async throws -> DeepgramSocketMessage? {
        guard !closed else { throw TranscriptionError.connectionClosed }
        let message: URLSessionWebSocketTask.Message
        do {
            message = try await task.receive()
        } catch {
            if task.closeCode == .normalClosure {
                return nil
            }
            throw error
        }
        switch message {
        case let .data(data):
            return .data(data)
        case let .string(text):
            return .text(text)
        @unknown default:
            throw TranscriptionError.invalidProviderMessage
        }
    }

    func close() async {
        guard !closed else { return }
        closed = true
        task.cancel(with: .normalClosure, reason: nil)
        session.invalidateAndCancel()
    }
}
