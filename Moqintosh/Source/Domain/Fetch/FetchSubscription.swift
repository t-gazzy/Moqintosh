//
//  FetchSubscription.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

public struct FetchSubscription: Sendable {

    public let requestID: UInt64
    public let resource: TrackResource
    public let subscriberPriority: UInt8
    public let groupOrder: GroupOrder
    public let endOfTrack: Bool
    public let endLocation: Location
    public let maxCacheDuration: UInt64?

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
