//
//  Session.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// Represents a MOQT session created from an Endpoint.
/// Use this to create a Publisher or Subscriber.
public final class Session {

    let context: SessionContext
    private let controlMessageReceiver: ControlMessageReceiver
    private let streamReceiverCoordinator: StreamReceiverCoordinator
    private let delegateQueue: DispatchQueue
    public weak var delegate: (any SessionDelegate)?

    init(sessionContext: SessionContext, controlMessageReceiver: ControlMessageReceiver) {
        self.context = sessionContext
        self.controlMessageReceiver = controlMessageReceiver
        self.streamReceiverCoordinator = .init(sessionContext: sessionContext)
        self.delegateQueue = .init(label: "Moqintosh.SessionDelegate")
        self.context.session = self
        self.context.connection.delegate = streamReceiverCoordinator
        self.controlMessageReceiver.start()
    }

    // MARK: - Factory

    public func makePublisher() -> Publisher {
        Publisher(sessionContext: context)
    }

    public func makeSubscriber() -> Subscriber {
        Subscriber(sessionContext: context)
    }

    func shouldAcceptPublishNamespace(prefix: TrackNamespace, authorizationToken: AuthorizationToken?) -> Bool {
        delegateQueue.sync {
            let isAccepted: Bool = delegate?.session(
                self,
                shouldAcceptPublishNamespace: prefix,
                authorizationToken: authorizationToken
            ) ?? false
            delegate?.session(
                self,
                didReceivePublishNamespace: prefix,
                authorizationToken: authorizationToken
            )
            return isAccepted
        }
    }

    func shouldAcceptPublish(resource: TrackResource) -> Bool {
        delegateQueue.sync {
            delegate?.session(self, didReceivePublish: resource) ?? false
        }
    }

    func shouldAcceptSubscribeNamespace(prefix: TrackNamespace, authorizationToken: AuthorizationToken?) -> Bool {
        delegateQueue.sync {
            let isAccepted: Bool = delegate?.session(
                self,
                shouldAcceptSubscribeNamespace: prefix,
                authorizationToken: authorizationToken
            ) ?? false
            delegate?.session(
                self,
                didReceiveSubscribeNamespace: prefix,
                authorizationToken: authorizationToken
            )
            return isAccepted
        }
    }

    func shouldAcceptSubscribe(publishedTrack: PublishedTrack) -> Bool {
        delegateQueue.sync {
            delegate?.session(self, didReceiveSubscribe: publishedTrack) ?? false
        }
    }
}

/// Errors thrown when a namespace subscription is rejected by the remote publisher.
public enum SubscribeNamespaceError: Error {
    case rejected(code: UInt64, reason: String)
}

/// Errors thrown when a subscription request is rejected by the remote publisher.
public enum SubscribeError: Error {
    case rejected(code: UInt64, reason: String)
}

/// Errors thrown when a namespace publish request is rejected by the remote subscriber.
public enum PublishNamespaceError: Error {
    case rejected(code: UInt64, reason: String)
}

/// Errors thrown when a publish request is rejected by the remote subscriber.
public enum PublishError: Error {
    case rejected(code: UInt64, reason: String)
}
