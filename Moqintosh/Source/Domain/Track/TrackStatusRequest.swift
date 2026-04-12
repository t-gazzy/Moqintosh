//
//  TrackStatusRequest.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

public struct TrackStatusRequest {

    public let requestID: UInt64
    public let resource: TrackResource
    public let subscriberPriority: UInt8
    public let groupOrder: GroupOrder
    public let forward: Bool
    public let filter: SubscriptionFilter

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
