//
//  DatagramSender.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Sends `OBJECT_DATAGRAM` frames for a published track.
public actor DatagramSender {

    /// The published track associated with this sender.
    public nonisolated let publishedTrack: PublishedTrack

    private let sessionContext: SessionContext

    init(sessionContext: SessionContext, publishedTrack: PublishedTrack) {
        self.sessionContext = sessionContext
        self.publishedTrack = publishedTrack
    }

    /// Sends an object datagram for the published track.
    public func send(
        groupID: UInt64,
        objectID: ObjectDatagram.ObjectID,
        publisherPriority: UInt8 = 0,
        endOfGroup: Bool = false,
        content: ObjectDatagram.Content
    ) async throws {
        let datagram: ObjectDatagram = ObjectDatagram(
            trackAlias: publishedTrack.trackAlias,
            groupID: groupID,
            objectID: objectID,
            publisherPriority: publisherPriority,
            endOfGroup: endOfGroup,
            content: content
        )
        OSLogger.debug("Sending OBJECT_DATAGRAM (trackAlias: \(publishedTrack.trackAlias), groupID: \(groupID))")
        try await sessionContext.sendDatagram(bytes: datagram.encode())
    }
}
