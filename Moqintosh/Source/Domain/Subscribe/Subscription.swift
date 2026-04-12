//
//  Subscription.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

/// Metadata for an active subscription.
public struct Subscription: Sendable {

    public let requestID: UInt64
    public let publishedTrack: PublishedTrack
    public let expires: UInt64
    public let subscriberPriority: UInt8
    public let filter: SubscriptionFilter

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
