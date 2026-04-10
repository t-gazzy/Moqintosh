//
//  Session.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

/// Represents a MOQT session created from an Endpoint.
/// Use this to create a Publisher or Subscriber.
public final class Session {

    let connection: any TransportConnection
    let controlStream: any TransportBiStream
    public weak var delegate: (any SessionDelegate)?

    /// Client-side Request IDs start at 0 and increment by 2 (even numbers, Section 9.1).
    private var nextRequestID: UInt64 = 0

    /// Pending continuations keyed by Request ID, waiting for a namespace subscription response.
    private var pendingNamespaceRequests: [UInt64: CheckedContinuation<Void, Error>] = [:]

    init(connection: any TransportConnection, controlStream: any TransportBiStream) {
        self.connection = connection
        self.controlStream = controlStream
        startReceiveLoop()
    }

    // MARK: - Request ID

    /// Issues the next Request ID and advances the counter.
    func issueRequestID() -> UInt64 {
        let id = nextRequestID
        nextRequestID += 2
        return id
    }

    // MARK: - Pending request tracking

    func addPendingNamespaceRequest(_ id: UInt64, continuation: CheckedContinuation<Void, Error>) {
        pendingNamespaceRequests[id] = continuation
    }

    func resolvePendingNamespaceRequest(with message: SubscribeNamespaceOKMessage) {
        guard let continuation = pendingNamespaceRequests.removeValue(forKey: message.requestID) else { return }
        continuation.resume()
    }

    func rejectPendingNamespaceRequest(with message: SubscribeNamespaceErrorMessage) {
        guard let continuation = pendingNamespaceRequests.removeValue(forKey: message.requestID) else { return }
        continuation.resume(throwing: SubscribeNamespaceError.rejected(code: message.errorCode, reason: message.reasonPhrase))
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
        case .subscribeNamespaceOK(let msg):
            resolvePendingNamespaceRequest(with: msg)
        case .subscribeNamespaceError(let msg):
            rejectPendingNamespaceRequest(with: msg)
        case .subscribe:
            delegate?.session(self, didReceiveSubscribe: "subscribe")
        case .subscribeUpdate:
            delegate?.session(self, didReceiveSubscribeUpdate: "subscribeUpdate")
        case .unsubscribe:
            delegate?.session(self, didReceiveUnsubscribe: "unsubscribe")
        case .fetch:
            delegate?.session(self, didReceiveFetch: "fetch")
        case .fetchCancel:
            delegate?.session(self, didReceiveFetchCancel: "fetchCancel")
        case .trackStatus:
            delegate?.session(self, didReceiveTrackStatus: "trackStatus")
        case .publish:
            delegate?.session(self, didReceivePublish: "publish")
        case .publishDone:
            delegate?.session(self, didReceivePublishDone: "publishDone")
        case .publishNamespace:
            delegate?.session(self, didReceivePublishNamespace: "publishNamespace")
        case .publishNamespaceDone:
            delegate?.session(self, didReceivePublishNamespaceDone: "publishNamespaceDone")
        default:
            OSLogger.debug("Unhandled message: \(message)")
        }
    }

    // MARK: - Factory

    public func makePublisher() -> Publisher {
        Publisher(session: self)
    }

    public func makeSubscriber() -> Subscriber {
        Subscriber(session: self)
    }
}

/// Errors thrown when a namespace subscription is rejected by the remote publisher.
public enum SubscribeNamespaceError: Error {
    case rejected(code: UInt64, reason: String)
}
