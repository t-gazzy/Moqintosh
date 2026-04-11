//
//  Subscriber.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

/// Represents a MOQT subscriber created from a Session.
///
/// A subscriber is the receiving side of a track.
/// Use the methods below to request tracks and namespaces.
public final class Subscriber {

    private let controlMessageChannel: any ControlMessageChannel
    private let sessionContext: SessionContext

    init(sessionContext: SessionContext) {
        self.controlMessageChannel = sessionContext
        self.sessionContext = sessionContext
    }

    // MARK: - Namespace

    /// Requests a namespace subscription and waits for acceptance or rejection (Section 9.28).
    ///
    /// - Parameter namespacePrefix: The track namespace prefix to subscribe to.
    /// - Throws: `SubscribeNamespaceError.rejected` if the publisher responds with `SUBSCRIBE_NAMESPACE_ERROR`.
    public func subscribeNamespace(namespacePrefix: TrackNamespace) async throws {
        let requestID: UInt64 = try await controlMessageChannel.issueRequestID()
        let message: SubscribeNamespaceMessage = SubscribeNamespaceMessage(requestID: requestID, namespacePrefix: namespacePrefix)
        OSLogger.debug("Sending SUBSCRIBE_NAMESPACE (requestID: \(requestID))")
        try await controlMessageChannel.performSubscribeNamespaceRequest(requestID: requestID, bytes: message.encode())
    }

    // MARK: - Subscribe

    /// Requests a subscription to a track (Section 9.7).
    public func subscribe(
        resource: TrackResource,
        subscriberPriority: UInt8 = 0,
        groupOrder: GroupOrder = .publisherDefault,
        forward: Bool = true,
        filter: SubscriptionFilter = .largestObject
    ) async throws -> Subscription {
        let requestID: UInt64 = try await controlMessageChannel.issueRequestID()
        let message: SubscribeMessage = SubscribeMessage(
            requestID: requestID,
            resource: resource,
            subscriberPriority: subscriberPriority,
            groupOrder: groupOrder,
            forward: forward,
            filter: filter,
            deliveryTimeout: nil
        )
        OSLogger.debug("Sending SUBSCRIBE (requestID: \(requestID))")
        return try await controlMessageChannel.performSubscribeRequest(
            requestID: requestID,
            resource: resource,
            subscriberPriority: subscriberPriority,
            requestedGroupOrder: groupOrder,
            forward: forward,
            filter: filter,
            bytes: message.encode()
        )
    }

    /// Updates an existing subscription (Section 9.10).
    public func subscribeUpdate(
        for subscription: Subscription,
        start: Location,
        endGroup: UInt64,
        subscriberPriority: UInt8? = nil,
        forward: Bool? = nil,
        authorizationToken: AuthorizationToken? = nil
    ) async throws {
        let message: SubscribeUpdateMessage = SubscribeUpdateMessage(
            requestID: subscription.requestID,
            start: start,
            endGroup: endGroup,
            subscriberPriority: subscriberPriority ?? subscription.subscriberPriority,
            forward: forward ?? subscription.publishedTrack.forward,
            authorizationToken: authorizationToken
        )
        OSLogger.debug("Sending SUBSCRIBE_UPDATE (requestID: \(subscription.requestID))")
        try await controlMessageChannel.sendControlMessage(bytes: message.encode())
    }

    /// Cancels a subscription (Section 9.11).
    public func unsubscribe(for subscription: Subscription) async throws {
        let message: UnsubscribeMessage = UnsubscribeMessage(requestID: subscription.requestID)
        OSLogger.debug("Sending UNSUBSCRIBE (requestID: \(subscription.requestID))")
        try await controlMessageChannel.sendControlMessage(bytes: message.encode())
    }

    // MARK: - Fetch

    /// Requests a fetch for a range of objects (Section 9.16).
    public func fetch(
        resource: TrackResource,
        subscriberPriority: UInt8 = 0,
        groupOrder: GroupOrder = .publisherDefault,
        start: Location,
        end: Location
    ) async throws -> FetchSubscription {
        let requestID: UInt64 = try await controlMessageChannel.issueRequestID()
        let message: FetchMessage = FetchMessage(
            requestID: requestID,
            subscriberPriority: subscriberPriority,
            groupOrder: groupOrder,
            mode: .standalone(resource: resource, start: start, end: end)
        )
        OSLogger.debug("Sending FETCH (requestID: \(requestID))")
        return try await controlMessageChannel.performFetchRequest(
            requestID: requestID,
            resource: resource,
            subscriberPriority: subscriberPriority,
            bytes: message.encode()
        )
    }

    public func fetch(
        joining subscription: Subscription,
        subscriberPriority: UInt8 = 0,
        groupOrder: GroupOrder = .publisherDefault,
        startGroupOffset: UInt64
    ) async throws -> FetchSubscription {
        let requestID: UInt64 = try await controlMessageChannel.issueRequestID()
        let message: FetchMessage = FetchMessage(
            requestID: requestID,
            subscriberPriority: subscriberPriority,
            groupOrder: groupOrder,
            mode: .joiningRelative(
                joiningRequestID: subscription.requestID,
                startGroupOffset: startGroupOffset
            )
        )
        OSLogger.debug("Sending FETCH (requestID: \(requestID))")
        return try await controlMessageChannel.performFetchRequest(
            requestID: requestID,
            resource: subscription.publishedTrack.resource,
            subscriberPriority: subscriberPriority,
            bytes: message.encode()
        )
    }

    public func fetch(
        joining subscription: Subscription,
        subscriberPriority: UInt8 = 0,
        groupOrder: GroupOrder = .publisherDefault,
        startGroup: UInt64
    ) async throws -> FetchSubscription {
        let requestID: UInt64 = try await controlMessageChannel.issueRequestID()
        let message: FetchMessage = FetchMessage(
            requestID: requestID,
            subscriberPriority: subscriberPriority,
            groupOrder: groupOrder,
            mode: .joiningAbsolute(
                joiningRequestID: subscription.requestID,
                startGroup: startGroup
            )
        )
        OSLogger.debug("Sending FETCH (requestID: \(requestID))")
        return try await controlMessageChannel.performFetchRequest(
            requestID: requestID,
            resource: subscription.publishedTrack.resource,
            subscriberPriority: subscriberPriority,
            bytes: message.encode()
        )
    }

    /// Cancels an in-progress fetch (Section 9.19).
    public func fetchCancel(for fetchSubscription: FetchSubscription) async throws {
        let message: FetchCancelMessage = FetchCancelMessage(requestID: fetchSubscription.requestID)
        OSLogger.debug("Sending FETCH_CANCEL (requestID: \(fetchSubscription.requestID))")
        try await controlMessageChannel.sendControlMessage(bytes: message.encode())
    }

    // MARK: - Track status

    /// Requests the current status of a track (Section 9.20).
    public func trackStatus(
        resource: TrackResource,
        subscriberPriority: UInt8 = 0,
        groupOrder: GroupOrder = .publisherDefault,
        forward: Bool = true,
        filter: SubscriptionFilter = .largestObject
    ) async throws -> TrackStatus {
        let requestID: UInt64 = try await controlMessageChannel.issueRequestID()
        let message: TrackStatusMessage = TrackStatusMessage(
            requestID: requestID,
            resource: resource,
            subscriberPriority: subscriberPriority,
            groupOrder: groupOrder,
            forward: forward,
            filter: filter
        )
        OSLogger.debug("Sending TRACK_STATUS (requestID: \(requestID))")
        return try await controlMessageChannel.performTrackStatusRequest(requestID: requestID, bytes: message.encode())
    }

    public func publishNamespaceCancel(
        trackNamespace: TrackNamespace,
        errorCode: UInt64,
        reasonPhrase: String
    ) async throws {
        let message: PublishNamespaceCancelMessage = PublishNamespaceCancelMessage(
            trackNamespace: trackNamespace,
            errorCode: errorCode,
            reasonPhrase: reasonPhrase
        )
        OSLogger.debug("Sending PUBLISH_NAMESPACE_CANCEL")
        try await controlMessageChannel.sendControlMessage(bytes: message.encode())
    }

    public func unsubscribeNamespace(namespacePrefix: TrackNamespace) async throws {
        let message: UnsubscribeNamespaceMessage = UnsubscribeNamespaceMessage(namespacePrefix: namespacePrefix)
        OSLogger.debug("Sending UNSUBSCRIBE_NAMESPACE")
        try await controlMessageChannel.sendControlMessage(bytes: message.encode())
    }

    public func makeStreamReceiverFactory(for subscription: Subscription) -> StreamReceiverFactory {
        StreamReceiverFactory(sessionContext: sessionContext, subscription: subscription)
    }

    public func makeDatagramReceiver(for subscription: Subscription) -> DatagramReceiver {
        DatagramReceiver(sessionContext: sessionContext, subscription: subscription)
    }

    public func makeFetchReceiverFactory(for fetchSubscription: FetchSubscription) -> FetchReceiverFactory {
        FetchReceiverFactory(sessionContext: sessionContext, fetchSubscription: fetchSubscription)
    }
}
