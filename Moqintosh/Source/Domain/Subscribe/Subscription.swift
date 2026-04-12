//
//  Subscription.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

/// Metadata for an active subscription.
public struct Subscription: Sendable {

    /// The request identifier assigned to the subscription.
    public let requestID: UInt64
    /// The published track accepted by the publisher.
    public let publishedTrack: PublishedTrack
    /// The expiry advertised in `SUBSCRIBE_OK`.
    public let expires: UInt64
    /// The subscriber priority associated with the subscription.
    public let subscriberPriority: UInt8
    /// The resolved filter associated with the subscription.
    public let filter: SubscriptionFilter

    /// Creates subscription metadata.
    public init(
        requestID: UInt64,
        publishedTrack: PublishedTrack,
        expires: UInt64,
        subscriberPriority: UInt8,
        filter: SubscriptionFilter
    ) {
        self.requestID = requestID
        self.publishedTrack = publishedTrack
        self.expires = expires
        self.subscriberPriority = subscriberPriority
        self.filter = filter
    }
}
