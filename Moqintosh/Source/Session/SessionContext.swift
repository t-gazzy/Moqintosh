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
    private var nextTrackAlias: UInt64 = 0

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
    }

    // MARK: - Pending request tracking

    func addRequest(_ id: UInt64, continuation: CheckedContinuation<Void, Error>) {
        requests[id] = continuation
    }

    func addPublishRequest(
        _ id: UInt64,
        publishedTrack: PublishedTrack,
        continuation: CheckedContinuation<PublishedTrack, Error>
    ) {
        publishRequests[id] = (publishedTrack: publishedTrack, continuation: continuation)
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
        subscribeRequests[id] = (
            resource: resource,
            subscriberPriority: subscriberPriority,
            requestedGroupOrder: requestedGroupOrder,
            forward: forward,
            filter: filter,
            continuation: continuation
        )
    }

    func resolveRequest(with message: PublishNamespaceOKMessage) {
        guard let continuation = requests.removeValue(forKey: message.requestID) else { return }
        continuation.resume()
    }

    func rejectRequest(with message: PublishNamespaceErrorMessage) {
        guard let continuation = requests.removeValue(forKey: message.requestID) else { return }
        continuation.resume(throwing: PublishNamespaceError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    func resolvePublishRequest(with message: PublishOKMessage) {
        guard let request = publishRequests.removeValue(forKey: message.requestID) else { return }
        request.continuation.resume(returning: request.publishedTrack)
    }

    func rejectPublishRequest(with message: PublishErrorMessage) {
        guard let request = publishRequests.removeValue(forKey: message.requestID) else { return }
        request.continuation.resume(throwing: PublishError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    func resolveRequest(with message: SubscribeNamespaceOKMessage) {
        guard let continuation = requests.removeValue(forKey: message.requestID) else { return }
        continuation.resume()
    }

    func rejectRequest(with message: SubscribeNamespaceErrorMessage) {
        guard let continuation = requests.removeValue(forKey: message.requestID) else { return }
        continuation.resume(throwing: SubscribeNamespaceError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    func resolveSubscribeRequest(with message: SubscribeOKMessage) {
        guard let request = subscribeRequests.removeValue(forKey: message.requestID) else { return }
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
        guard let request = subscribeRequests.removeValue(forKey: message.requestID) else { return }
        request.continuation.resume(throwing: SubscribeError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    // MARK: - Request ID

    /// Issues the next Request ID and advances the counter.
    func issueRequestID() -> UInt64 {
        let id = nextRequestID
        nextRequestID += 2
        return id
    }

    func issueTrackAlias() -> UInt64 {
        let alias: UInt64 = nextTrackAlias
        nextTrackAlias += 1
        return alias
    }
}
