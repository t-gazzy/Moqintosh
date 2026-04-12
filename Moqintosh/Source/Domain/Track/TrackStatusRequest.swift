//
//  TrackStatusRequest.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

/// Represents an inbound `TRACK_STATUS` request.
public struct TrackStatusRequest {

    /// The request identifier associated with the query.
    public let requestID: UInt64
    /// The queried track resource.
    public let resource: TrackResource
    /// The subscriber priority requested by the peer.
    public let subscriberPriority: UInt8
    /// The group ordering requested by the peer.
    public let groupOrder: GroupOrder
    /// Whether forwarding is requested by the peer.
    public let forward: Bool
    /// The filter requested by the peer.
    public let filter: SubscriptionFilter

    /// Creates a track-status request value.
    public init(
        requestID: UInt64,
        resource: TrackResource,
        subscriberPriority: UInt8,
        groupOrder: GroupOrder,
        forward: Bool,
        filter: SubscriptionFilter
    ) {
        self.requestID = requestID
        self.resource = resource
        self.subscriberPriority = subscriberPriority
        self.groupOrder = groupOrder
        self.forward = forward
        self.filter = filter
    }
}
