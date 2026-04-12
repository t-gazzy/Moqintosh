//
//  StreamSender.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Synchronization

// Safe because mutable send state is serialized through previousObjectID.
/// Sends objects on a single subgroup stream.
public final class StreamSender: @unchecked Sendable {

    /// The payload or terminal status carried by a subgroup object.
    public enum Content {
        case payload(Data)
        case status(UInt64)
    }

    private let stream: TransportUniSendStream
    private let header: SubgroupHeader
    private let previousObjectID: Mutex<UInt64?>

    init(stream: TransportUniSendStream, header: SubgroupHeader) {
        self.stream = stream
        self.header = header
        self.previousObjectID = Mutex<UInt64?>(nil)
    }

    /// Sends a subgroup object and keeps the stream open.
    public func send(objectID: UInt64, content: Content) async throws {
        try await send(objectID: objectID, endOfGroup: false, extensions: [], content: content)
    }

    /// Sends a subgroup object and optionally marks the end of the group.
    public func send(objectID: UInt64, endOfGroup: Bool, content: Content) async throws {
        try await send(objectID: objectID, endOfGroup: endOfGroup, extensions: [], content: content)
    }

    func send(
        objectID: UInt64,
        endOfGroup: Bool,
        extensions: [KeyValuePair],
        content: Content
    ) async throws {
        let subgroupObject: SubgroupObject = previousObjectID.withLock { previousObjectID in
            let subgroupObject: SubgroupObject = header.makeObject(
                previousObjectID: previousObjectID,
                objectID: objectID,
                extensions: extensions,
                content: content.subgroupObjectContent
            )
            previousObjectID = objectID
            return subgroupObject
        }
        try await stream.send(bytes: subgroupObject.encode(), endOfStream: endOfGroup)
    }
}

private extension StreamSender.Content {
    var subgroupObjectContent: SubgroupObject.Content {
        switch self {
        case .payload(let payload):
            return .payload(payload)
        case .status(let status):
            return .status(status)
        }
    }
}
