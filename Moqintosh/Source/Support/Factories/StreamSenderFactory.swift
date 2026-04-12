//
//  StreamSenderFactory.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

// Safe because the factory forwards stream creation into SessionContext and does not maintain mutable shared state.
/// Creates subgroup stream senders for a published track.
public final class StreamSenderFactory: @unchecked Sendable {

    private let sessionContext: SessionContext
    /// The published track associated with senders created by this factory.
    public let publishedTrack: PublishedTrack

    init(sessionContext: SessionContext, publishedTrack: PublishedTrack) {
        self.sessionContext = sessionContext
        self.publishedTrack = publishedTrack
    }

    /// Opens a new subgroup send stream and returns a sender for the supplied header values.
    public func makeSender(
        groupID: UInt64,
        subgroupID: SubgroupHeader.SubgroupID = .zero,
        publisherPriority: UInt8 = 0,
        usesExtensions: Bool = false,
        containsEndOfGroup: Bool = false
    ) async throws -> StreamSender {
        let stream: TransportUniSendStream = try await sessionContext.connection.openUniStream()
        let header: SubgroupHeader = SubgroupHeader(
            trackAlias: publishedTrack.trackAlias,
            groupID: groupID,
            subgroupID: subgroupID,
            publisherPriority: publisherPriority,
            usesExtensions: usesExtensions,
            containsEndOfGroup: containsEndOfGroup
        )
        try await stream.send(bytes: header.encode(), endOfStream: false)
        return StreamSender(stream: stream, header: header)
    }
}
