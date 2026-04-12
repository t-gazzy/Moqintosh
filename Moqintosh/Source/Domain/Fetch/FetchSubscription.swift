//
//  FetchSubscription.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

/// Metadata for an active fetch request.
public struct FetchSubscription: Sendable {

    /// The request identifier assigned to the fetch.
    public let requestID: UInt64
    /// The fetched track resource.
    public let resource: TrackResource
    /// The subscriber priority associated with the fetch.
    public let subscriberPriority: UInt8
    /// The resolved group ordering for the fetch.
    public let groupOrder: GroupOrder
    /// Whether the fetch reaches the end of the track.
    public let endOfTrack: Bool
    /// The ending location returned by the publisher.
    public let endLocation: Location
    /// The optional cache duration returned by the publisher.
    public let maxCacheDuration: UInt64?

    /// Creates fetch subscription metadata.
    public init(
        requestID: UInt64,
        resource: TrackResource,
        subscriberPriority: UInt8,
        groupOrder: GroupOrder,
        endOfTrack: Bool,
        endLocation: Location,
        maxCacheDuration: UInt64?
    ) {
        self.requestID = requestID
        self.resource = resource
        self.subscriberPriority = subscriberPriority
        self.groupOrder = groupOrder
        self.endOfTrack = endOfTrack
        self.endLocation = endLocation
        self.maxCacheDuration = maxCacheDuration
    }
}
