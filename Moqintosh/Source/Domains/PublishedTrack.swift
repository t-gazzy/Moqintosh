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
    public let contentExist: ContentExist
    public let forward: Bool

    public init(
        requestID: UInt64,
        resource: TrackResource,
        trackAlias: UInt64,
        groupOrder: GroupOrder,
        contentExist: ContentExist,
        forward: Bool
    ) {
        self.requestID = requestID
        self.resource = resource
        self.trackAlias = trackAlias
        self.groupOrder = groupOrder
        self.contentExist = contentExist
        self.forward = forward
    }
}
