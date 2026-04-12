//
//  DatagramSender.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

// Safe because the sender forwards directly into SessionContext and does not maintain mutable shared state.
/// Sends `OBJECT_DATAGRAM` frames for a published track.
public final class DatagramSender: @unchecked Sendable {

    /// The published track associated with this sender.
    public let publishedTrack: PublishedTrack

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
        try await sessionContext.connection.sendDatagram(bytes: datagram.encode())
    }
}
