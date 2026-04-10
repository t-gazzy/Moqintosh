//
//  PublishedTrack.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

/// Metadata for a published track.
public struct PublishedTrack {

    public let requestID: UInt64
    public let resource: TrackResource
    public let trackAlias: UInt64
    public let groupOrder: GroupOrder
    public let contentExists: Bool
    public let largestLocation: Location?
    public let forward: Bool

    public init(
        requestID: UInt64,
        resource: TrackResource,
        trackAlias: UInt64,
        groupOrder: GroupOrder,
        contentExists: Bool,
        largestLocation: Location?,
        forward: Bool
    ) {
        self.requestID = requestID
        self.resource = resource
        self.trackAlias = trackAlias
        self.groupOrder = groupOrder
        self.contentExists = contentExists
        self.largestLocation = largestLocation
        self.forward = forward
    }
}
