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

    public let session: Session

    init(session: Session) {
        self.session = session
    }

    // MARK: - Namespace

    /// Requests a namespace subscription and waits for acceptance or rejection (Section 9.28).
    ///
    /// - Parameter namespacePrefix: The track namespace prefix to subscribe to.
    /// - Throws: `SubscribeNamespaceError.rejected` if the publisher responds with `SUBSCRIBE_NAMESPACE_ERROR`.
    public func subscribeNamespace(namespacePrefix: TrackNamespace) async throws {
        let requestID: UInt64 = session.context.issueRequestID()
        let message: SubscribeNamespaceMessage = .init(requestID: requestID, namespacePrefix: namespacePrefix)
        try await withCheckedThrowingContinuation { continuation in
            session.context.requestStore.addRequest(requestID, continuation: continuation)
            Task {
                do {
                    OSLogger.debug("Sending SUBSCRIBE_NAMESPACE (requestID: \(requestID))")
                    try await self.session.context.controlStream.send(bytes: message.encode())
                } catch {
                    self.session.context.requestStore.failRequest(requestID, error: error)
                }
            }
        }
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
        let requestID: UInt64 = session.context.issueRequestID()
        let message: SubscribeMessage = .init(
            requestID: requestID,
            resource: resource,
            subscriberPriority: subscriberPriority,
            groupOrder: groupOrder,
            forward: forward,
            filter: filter,
            deliveryTimeout: nil
        )
        return try await withCheckedThrowingContinuation { continuation in
            session.context.requestStore.addSubscribeRequest(
                requestID,
                resource: resource,
                subscriberPriority: subscriberPriority,
                requestedGroupOrder: groupOrder,
                forward: forward,
                filter: filter,
                continuation: continuation
            )
            Task {
                do {
                    OSLogger.debug("Sending SUBSCRIBE (requestID: \(requestID))")
                    try await self.session.context.controlStream.send(bytes: message.encode())
                } catch {
                    self.session.context.requestStore.failSubscribeRequest(requestID, error: error)
                }
            }
        }
    }

    /// Updates an existing subscription (Section 9.10).
    public func subscribeUpdate() async throws {
        // TODO: encode and send SUBSCRIBE_UPDATE
    }

    /// Cancels a subscription (Section 9.11).
    public func unsubscribe() async throws {
        // TODO: encode and send UNSUBSCRIBE
    }

    // MARK: - Fetch

    /// Requests a fetch for a range of objects (Section 9.16).
    public func fetch() async throws {
        // TODO: encode and send FETCH
    }

    /// Cancels an in-progress fetch (Section 9.19).
    public func fetchCancel() async throws {
        // TODO: encode and send FETCH_CANCEL
    }

    // MARK: - Track status

    /// Requests the current status of a track (Section 9.20).
    public func trackStatus() async throws {
        // TODO: encode and send TRACK_STATUS
    }

    public func makeStreamReceiverFactory(for subscription: Subscription) -> StreamReceiverFactory {
        .init(session: session, subscription: subscription)
    }
}
