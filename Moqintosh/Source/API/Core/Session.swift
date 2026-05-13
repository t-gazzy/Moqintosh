//
//  Session.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation
import Synchronization

/// Represents a MOQT session created from an Endpoint.
/// Use this to create a Publisher or Subscriber.
public final class Session: Sendable {

    private struct DelegateStorage {
        weak var delegate: (any SessionDelegate)?
    }

    let context: SessionContext
    private let controlMessageReceiver: ControlMessageReceiver
    private let streamReceiverCoordinator: StreamReceiverCoordinator
    private let delegateStorage: Mutex<DelegateStorage>

    /// The delegate that receives inbound control message events.
    public var delegate: (any SessionDelegate)? {
        get {
            delegateStorage.withLock { storage in
                storage.delegate
            }
        }
        set {
            delegateStorage.withLock { storage in
                storage.delegate = newValue
            }
        }
    }

    init(sessionContext: SessionContext, controlMessageReceiver: ControlMessageReceiver) {
        self.context = sessionContext
        self.controlMessageReceiver = controlMessageReceiver
        self.streamReceiverCoordinator = StreamReceiverCoordinator(sessionContext: sessionContext)
        self.delegateStorage = Mutex<DelegateStorage>(DelegateStorage(delegate: nil))
    }

    func start() async {
        await context.setSession(self)
        await context.setConnectionDelegate(streamReceiverCoordinator)
        controlMessageReceiver.start(dispatcher: ControlMessageDispatcher(sessionContext: context))
    }

    // MARK: - Factory

    /// Creates a publisher bound to this session.
    public func makePublisher() -> Publisher {
        Publisher(sessionContext: context)
    }

    /// Creates a subscriber bound to this session.
    public func makeSubscriber() -> Subscriber {
        Subscriber(sessionContext: context)
    }

    /// Sends GOAWAY to the remote peer and optionally advertises a replacement session URI.
    public func goAway(newSessionURI: String? = nil) async throws {
        let message: GoAwayMessage = GoAwayMessage(newSessionURI: newSessionURI)
        OSLogger.info("Sending GOAWAY")
        try await context.sendControlMessage(bytes: message.encode())
    }

    func didReceivePublishNamespace(
        prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) async -> PublishNamespaceDecision {
        await delegate?.session(
            self,
            didReceivePublishNamespace: prefix,
            authorizationToken: authorizationToken
        ) ?? .accept
    }

    func didReceivePublish(resource: TrackResource) async -> PublishDecision {
        await delegate?.session(self, didReceivePublish: resource)
            ?? .accept(PublishAcceptance())
    }

    func didReceiveSubscribeNamespace(
        prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) async -> SubscribeNamespaceDecision {
        await delegate?.session(
            self,
            didReceiveSubscribeNamespace: prefix,
            authorizationToken: authorizationToken
        ) ?? .accept
    }

    func didReceiveSubscribe(publishedTrack: PublishedTrack) async -> SubscribeDecision {
        await delegate?.session(self, didReceiveSubscribe: publishedTrack)
            ?? .accept(SubscribeAcceptance(publishedTrack: publishedTrack))
    }

    func didReceiveGoAway(newSessionURI: String?) async {
        await delegate?.session(self, didReceiveGoAway: newSessionURI)
    }

    func didReceiveSubscribeUpdate(_ update: SubscribeUpdate) async {
        await delegate?.session(self, didReceiveSubscribeUpdate: update)
    }

    func didReceiveUnsubscribe(requestID: UInt64) async {
        await delegate?.session(self, didReceiveUnsubscribe: requestID)
    }

    func fetchDecision(for request: FetchRequest) async -> FetchDecision {
        await delegate?.session(self, didReceiveFetch: request)
            ?? .reject(FetchRequestError(code: .trackDoesNotExist, reason: "Track does not exist"))
    }

    func didReceiveFetchCancel(requestID: UInt64) async {
        await delegate?.session(self, didReceiveFetchCancel: requestID)
    }

    func trackStatusDecision(for request: TrackStatusRequest) async -> TrackStatusDecision {
        await delegate?.session(self, didReceiveTrackStatus: request)
            ?? .reject(TrackStatusRequestError(code: .trackDoesNotExist, reason: "Track does not exist"))
    }

    func didReceivePublishDone(_ publishDone: PublishDone) async {
        await delegate?.session(self, didReceivePublishDone: publishDone)
    }

    func didReceivePublishNamespaceDone(trackNamespace: TrackNamespace) async {
        await delegate?.session(self, didReceivePublishNamespaceDone: trackNamespace)
    }

    func didReceivePublishNamespaceCancel(_ cancellation: PublishNamespaceCancel) async {
        await delegate?.session(self, didReceivePublishNamespaceCancel: cancellation)
    }

    func didReceiveUnsubscribeNamespace(namespacePrefix: TrackNamespace) async {
        await delegate?.session(self, didReceiveUnsubscribeNamespace: namespacePrefix)
    }
}

/// Errors thrown when a namespace subscription is rejected by the remote publisher.
public enum SubscribeNamespaceError: Error {
    /// The remote peer rejected the request with the supplied error code and reason.
    case rejected(code: UInt64, reason: String)
}

/// Errors thrown when a subscription request is rejected by the remote publisher.
public enum SubscribeError: Error {
    /// The remote peer rejected the request with the supplied error code and reason.
    case rejected(code: UInt64, reason: String)
}

/// Errors thrown when a namespace publish request is rejected by the remote subscriber.
public enum PublishNamespaceError: Error {
    /// The remote peer rejected the request with the supplied error code and reason.
    case rejected(code: UInt64, reason: String)
}

/// Errors thrown when a publish request is rejected by the remote subscriber.
public enum PublishError: Error {
    /// The remote peer rejected the request with the supplied error code and reason.
    case rejected(code: UInt64, reason: String)
}

/// Errors thrown when a track status request is rejected by the remote peer.
public enum TrackStatusError: Error {
    /// The remote peer rejected the request with the supplied error code and reason.
    case rejected(code: UInt64, reason: String)
}

/// Errors thrown when the remote peer blocks issuing more request IDs.
public enum SessionFlowControlError: Error {
    /// The peer advertised the current maximum request ID.
    case blocked(maxRequestID: UInt64)
}

/// Errors thrown when a fetch request is rejected by the remote peer.
public enum FetchError: Error {
    /// The remote peer rejected the request with the supplied error code and reason.
    case rejected(code: UInt64, reason: String)
}
