//
//  SessionContext.swift
//  Moqintosh
//
//  Created by Takemasa Kaji on 2026/04/10.
//

final class SessionContext {

    weak var session: Session?

    let connection: TransportConnection
    let controlStream: TransportBiStream
    /// Client-side Request IDs start at 0 and increment by 2 (even numbers, Section 9.1).
    private var nextRequestID: UInt64 = 0

    /// Pending continuations keyed by Request ID, waiting for a namespace subscription response.
    private var requests: [UInt64: CheckedContinuation<Void, Error>] = [:]

    init(connection: TransportConnection, controlStream: TransportBiStream) {
        self.connection = connection
        self.controlStream = controlStream
        startReceiveLoop()
    }

    // MARK: - Receive loop

    private func startReceiveLoop() {
        let reader = MessageFrameReader()
        Task { [weak self] in
            guard let self else { return }
            do {
                while true {
                    let message = try await reader.read(from: controlStream)
                    handle(message)
                }
            } catch {
                OSLogger.error("Control stream receive error: \(error)")
            }
        }
    }

    private func handle(_ message: MOQTMessage) {
        switch message {
        case .publishNamespace(let message):
            handleIncomingPublishNamespace(message)
        case .publishNamespaceOK(let msg):
            resolveRequest(with: msg)
        case .publishNamespaceError(let msg):
            rejectRequest(with: msg)
        case .subscribeNamespace(let message):
            handleIncomingSubscribeNamespace(message)
        case .subscribeNamespaceOK(let msg):
            resolveRequest(with: msg)
        case .subscribeNamespaceError(let msg):
            rejectRequest(with: msg)
        default:
            OSLogger.debug("Unhandled message: \(message)")
        }
    }

    // MARK: - Pending request tracking

    func addRequest(_ id: UInt64, continuation: CheckedContinuation<Void, Error>) {
        requests[id] = continuation
    }

    func resolveRequest(with message: PublishNamespaceOKMessage) {
        guard let continuation = requests.removeValue(forKey: message.requestID) else { return }
        continuation.resume()
    }

    func rejectRequest(with message: PublishNamespaceErrorMessage) {
        guard let continuation = requests.removeValue(forKey: message.requestID) else { return }
        continuation.resume(throwing: PublishNamespaceError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    func resolveRequest(with message: SubscribeNamespaceOKMessage) {
        guard let continuation = requests.removeValue(forKey: message.requestID) else { return }
        continuation.resume()
    }

    func rejectRequest(with message: SubscribeNamespaceErrorMessage) {
        guard let continuation = requests.removeValue(forKey: message.requestID) else { return }
        continuation.resume(throwing: SubscribeNamespaceError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    // MARK: - Request ID

    /// Issues the next Request ID and advances the counter.
    func issueRequestID() -> UInt64 {
        let id = nextRequestID
        nextRequestID += 2
        return id
    }

    private func handleIncomingPublishNamespace(_ message: PublishNamespaceMessage) {
        guard let session else { return }
        let authorizationToken: AuthorizationToken? = firstAuthorizationToken(in: message.parameters)
        let isAccepted: Bool = session.delegate?.session(
            session,
            shouldAcceptPublishNamespace: message.trackNamespace,
            authorizationToken: authorizationToken
        ) ?? false
        let response: Data = isAccepted
            ? PublishNamespaceOKMessage(requestID: message.requestID).encode()
            : PublishNamespaceErrorMessage(
                requestID: message.requestID,
                errorCode: 0x1,
                reasonPhrase: "Rejected"
            ).encode()
        Task {
            try await controlStream.send(bytes: response)
        }
    }

    private func handleIncomingSubscribeNamespace(_ message: SubscribeNamespaceMessage) {
        guard let session else { return }
        let authorizationToken: AuthorizationToken? = firstAuthorizationToken(in: message.parameters)
        let isAccepted: Bool = session.delegate?.session(
            session,
            shouldAcceptSubscribeNamespace: message.namespacePrefix,
            authorizationToken: authorizationToken
        ) ?? false
        let response: Data = isAccepted
            ? SubscribeNamespaceOKMessage(requestID: message.requestID).encode()
            : SubscribeNamespaceErrorMessage(
                requestID: message.requestID,
                errorCode: 0x1,
                reasonPhrase: "Rejected"
            ).encode()
        Task {
            try await controlStream.send(bytes: response)
        }
    }

    private func firstAuthorizationToken(in parameters: [SetupParameter]) -> AuthorizationToken? {
        for parameter in parameters {
            if case .authorizationToken(let token) = parameter {
                return token
            }
        }
        return nil
    }
}
