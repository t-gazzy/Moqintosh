//
//  StreamFactory.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

/// Creates subgroup stream senders for a published track.
public final class StreamFactory {

    private let session: Session
    public let publishedTrack: PublishedTrack

    init(session: Session, publishedTrack: PublishedTrack) {
        self.session = session
        self.publishedTrack = publishedTrack
    }

    public func makeSender(
        groupID: UInt64,
        subgroupID: SubgroupHeader.SubgroupID = .zero,
        publisherPriority: UInt8 = 0,
        usesExtensions: Bool = false,
        containsEndOfGroup: Bool = false
    ) async throws -> StreamSender {
        let stream: TransportUniStream = try await session.context.connection.openUniStream()
        let header: SubgroupHeader = .init(
            trackAlias: publishedTrack.trackAlias,
            groupID: groupID,
            subgroupID: subgroupID,
            publisherPriority: publisherPriority,
            usesExtensions: usesExtensions,
            containsEndOfGroup: containsEndOfGroup
        )
        try await stream.send(bytes: header.encode())
        return .init(stream: stream, header: header)
    }
}
