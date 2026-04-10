//
//  SessionContext.swift
//  Moqintosh
//
//  Created by Takemasa Kaji on 2026/04/10.
//

import Foundation

final class SessionContext {

    weak var session: Session?

    let connection: TransportConnection
    let controlStream: TransportBiStream
    /// Client-side Request IDs start at 0 and increment by 2 (even numbers, Section 9.1).
    private var nextRequestID: UInt64 = 0
    private var nextTrackAlias: UInt64 = 0
    private let stateQueue: DispatchQueue

    /// Pending continuations keyed by Request ID, waiting for a namespace subscription response.
    private var requests: [UInt64: CheckedContinuation<Void, Error>] = [:]
    private var publishRequests: [UInt64: (publishedTrack: PublishedTrack, continuation: CheckedContinuation<PublishedTrack, Error>)] = [:]
    private var subscribeRequests: [UInt64: (
        resource: TrackResource,
        subscriberPriority: UInt8,
        requestedGroupOrder: GroupOrder,
        forward: Bool,
        filter: SubscriptionFilter,
        continuation: CheckedContinuation<Subscription, Error>
    )] = [:]

    init(connection: TransportConnection, controlStream: TransportBiStream) {
        self.connection = connection
        self.controlStream = controlStream
        self.stateQueue = .init(label: "Moqintosh.SessionContext")
    }

    // MARK: - Pending request tracking

    func addRequest(_ id: UInt64, continuation: CheckedContinuation<Void, Error>) {
        stateQueue.sync {
            requests[id] = continuation
        }
    }

    func addPublishRequest(
        _ id: UInt64,
        publishedTrack: PublishedTrack,
        continuation: CheckedContinuation<PublishedTrack, Error>
    ) {
        stateQueue.sync {
            publishRequests[id] = (publishedTrack: publishedTrack, continuation: continuation)
        }
    }

    func addSubscribeRequest(
        _ id: UInt64,
        resource: TrackResource,
        subscriberPriority: UInt8,
        requestedGroupOrder: GroupOrder,
        forward: Bool,
        filter: SubscriptionFilter,
        continuation: CheckedContinuation<Subscription, Error>
    ) {
        stateQueue.sync {
            subscribeRequests[id] = (
                resource: resource,
                subscriberPriority: subscriberPriority,
                requestedGroupOrder: requestedGroupOrder,
                forward: forward,
                filter: filter,
                continuation: continuation
            )
        }
    }

    func resolveRequest(with message: PublishNamespaceOKMessage) {
        let continuation: CheckedContinuation<Void, Error>? = stateQueue.sync {
            requests.removeValue(forKey: message.requestID)
        }
        guard let continuation else { return }
        continuation.resume()
    }

    func rejectRequest(with message: PublishNamespaceErrorMessage) {
        let continuation: CheckedContinuation<Void, Error>? = stateQueue.sync {
            requests.removeValue(forKey: message.requestID)
        }
        guard let continuation else { return }
        continuation.resume(throwing: PublishNamespaceError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    func failRequest(_ id: UInt64, error: any Error) {
        let continuation: CheckedContinuation<Void, Error>? = stateQueue.sync {
            requests.removeValue(forKey: id)
        }
        guard let continuation else { return }
        continuation.resume(throwing: error)
    }

    func resolvePublishRequest(with message: PublishOKMessage) {
        let request: (publishedTrack: PublishedTrack, continuation: CheckedContinuation<PublishedTrack, Error>)? = stateQueue.sync {
            publishRequests.removeValue(forKey: message.requestID)
        }
        guard let request else { return }
        request.continuation.resume(returning: request.publishedTrack)
    }

    func rejectPublishRequest(with message: PublishErrorMessage) {
        let request: (publishedTrack: PublishedTrack, continuation: CheckedContinuation<PublishedTrack, Error>)? = stateQueue.sync {
            publishRequests.removeValue(forKey: message.requestID)
        }
        guard let request else { return }
        request.continuation.resume(throwing: PublishError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    func failPublishRequest(_ id: UInt64, error: any Error) {
        let request: (publishedTrack: PublishedTrack, continuation: CheckedContinuation<PublishedTrack, Error>)? = stateQueue.sync {
            publishRequests.removeValue(forKey: id)
        }
        guard let request else { return }
        request.continuation.resume(throwing: error)
    }

    func resolveRequest(with message: SubscribeNamespaceOKMessage) {
        let continuation: CheckedContinuation<Void, Error>? = stateQueue.sync {
            requests.removeValue(forKey: message.requestID)
        }
        guard let continuation else { return }
        continuation.resume()
    }

    func rejectRequest(with message: SubscribeNamespaceErrorMessage) {
        let continuation: CheckedContinuation<Void, Error>? = stateQueue.sync {
            requests.removeValue(forKey: message.requestID)
        }
        guard let continuation else { return }
        continuation.resume(throwing: SubscribeNamespaceError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    func resolveSubscribeRequest(with message: SubscribeOKMessage) {
        let request: (
            resource: TrackResource,
            subscriberPriority: UInt8,
            requestedGroupOrder: GroupOrder,
            forward: Bool,
            filter: SubscriptionFilter,
            continuation: CheckedContinuation<Subscription, Error>
        )? = stateQueue.sync {
            subscribeRequests.removeValue(forKey: message.requestID)
        }
        guard let request else { return }
        let publishedTrack: PublishedTrack = .init(
            requestID: message.requestID,
            resource: request.resource,
            trackAlias: message.trackAlias,
            groupOrder: message.groupOrder,
            contentExist: message.contentExist,
            forward: request.forward
        )
        let subscription: Subscription = .init(
            requestID: message.requestID,
            publishedTrack: publishedTrack,
            expires: message.expires,
            subscriberPriority: request.subscriberPriority,
            filter: request.filter
        )
        request.continuation.resume(returning: subscription)
    }

    func rejectSubscribeRequest(with message: SubscribeErrorMessage) {
        let request: (
            resource: TrackResource,
            subscriberPriority: UInt8,
            requestedGroupOrder: GroupOrder,
            forward: Bool,
            filter: SubscriptionFilter,
            continuation: CheckedContinuation<Subscription, Error>
        )? = stateQueue.sync {
            subscribeRequests.removeValue(forKey: message.requestID)
        }
        guard let request else { return }
        request.continuation.resume(throwing: SubscribeError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    func failSubscribeRequest(_ id: UInt64, error: any Error) {
        let request: (
            resource: TrackResource,
            subscriberPriority: UInt8,
            requestedGroupOrder: GroupOrder,
            forward: Bool,
            filter: SubscriptionFilter,
            continuation: CheckedContinuation<Subscription, Error>
        )? = stateQueue.sync {
            subscribeRequests.removeValue(forKey: id)
        }
        guard let request else { return }
        request.continuation.resume(throwing: error)
    }

    // MARK: - Request ID

    /// Issues the next Request ID and advances the counter.
    func issueRequestID() -> UInt64 {
        stateQueue.sync {
            let id: UInt64 = nextRequestID
            nextRequestID += 2
            return id
        }
    }

    func issueTrackAlias() -> UInt64 {
        stateQueue.sync {
            let alias: UInt64 = nextTrackAlias
            nextTrackAlias += 1
            return alias
        }
    }
}
