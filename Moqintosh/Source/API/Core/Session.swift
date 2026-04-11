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

    public func goAway(newSessionURI: String? = nil) async throws {
        let message: GoAwayMessage = .init(newSessionURI: newSessionURI)
        OSLogger.info("Sending GOAWAY")
        try await context.sendControlMessage(bytes: message.encode())
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

    func didReceiveGoAway(newSessionURI: String?) {
        delegateQueue.sync {
            delegate?.session(self, didReceiveGoAway: newSessionURI)
        }
    }

    func didReceiveSubscribeUpdate(_ update: SubscribeUpdate) {
        delegateQueue.sync {
            delegate?.session(self, didReceiveSubscribeUpdate: update)
        }
    }

    func didReceiveUnsubscribe(requestID: UInt64) {
        delegateQueue.sync {
            delegate?.session(self, didReceiveUnsubscribe: requestID)
        }
    }

    func fetchResponse(for request: FetchRequest) throws -> FetchResponse {
        try delegateQueue.sync {
            try delegate?.session(self, didReceiveFetch: request) ?? {
                throw FetchRequestError.rejected(code: 0x0, reason: "Rejected")
            }()
        }
    }

    func didReceiveFetchCancel(requestID: UInt64) {
        delegateQueue.sync {
            delegate?.session(self, didReceiveFetchCancel: requestID)
        }
    }

    func trackStatus(for request: TrackStatusRequest) throws -> TrackStatus {
        try delegateQueue.sync {
            try delegate?.session(self, didReceiveTrackStatus: request) ?? {
                throw TrackStatusRequestError.rejected(code: 0x0, reason: "Rejected")
            }()
        }
    }

    func didReceivePublishDone(_ publishDone: PublishDone) {
        delegateQueue.sync {
            delegate?.session(self, didReceivePublishDone: publishDone)
        }
    }

    func didReceivePublishNamespaceDone(trackNamespace: TrackNamespace) {
        delegateQueue.sync {
            delegate?.session(self, didReceivePublishNamespaceDone: trackNamespace)
        }
    }

    func didReceivePublishNamespaceCancel(_ cancellation: PublishNamespaceCancel) {
        delegateQueue.sync {
            delegate?.session(self, didReceivePublishNamespaceCancel: cancellation)
        }
    }

    func didReceiveUnsubscribeNamespace(namespacePrefix: TrackNamespace) {
        delegateQueue.sync {
            delegate?.session(self, didReceiveUnsubscribeNamespace: namespacePrefix)
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

public enum TrackStatusError: Error {
    case rejected(code: UInt64, reason: String)
}

public enum TrackStatusRequestError: Error {
    case rejected(code: UInt64, reason: String)
}

public enum SessionFlowControlError: Error {
    case blocked(maxRequestID: UInt64)
}

public enum FetchError: Error {
    case rejected(code: UInt64, reason: String)
}

public enum FetchRequestError: Error {
    case rejected(code: UInt64, reason: String)
}
