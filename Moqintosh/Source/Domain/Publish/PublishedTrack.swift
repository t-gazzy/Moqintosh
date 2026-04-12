//
//  PublishedTrack.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

/// Metadata for a published track.
public struct PublishedTrack: Sendable {

    /// The request identifier assigned to the publish.
    public let requestID: UInt64
    /// The published resource.
    public let resource: TrackResource
    /// The track alias assigned for data delivery.
    public let trackAlias: UInt64
    /// The group ordering associated with the publication.
    public let groupOrder: GroupOrder
    /// Whether content exists for the published track.
    public let contentExist: ContentExist
    /// Whether the publication may be forwarded.
    public let forward: Bool

    /// Creates published track metadata.
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
