//
//  DatagramSender.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

// Safe because the sender forwards directly into SessionContext and does not maintain mutable shared state.
public final class DatagramSender: @unchecked Sendable {

    public let publishedTrack: PublishedTrack

    private let sessionContext: SessionContext

    init(sessionContext: SessionContext, publishedTrack: PublishedTrack) {
        self.sessionContext = sessionContext
        self.publishedTrack = publishedTrack
    }

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
