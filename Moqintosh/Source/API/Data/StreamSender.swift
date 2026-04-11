//
//  StreamSender.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Sends objects on a single subgroup stream.
public final class StreamSender {

    public enum Content {
        case payload(Data)
        case status(UInt64)
    }

    private let stream: TransportUniSendStream
    private let header: SubgroupHeader
    private let stateQueue: DispatchQueue
    private var previousObjectID: UInt64?

    init(stream: TransportUniSendStream, header: SubgroupHeader) {
        self.stream = stream
        self.header = header
        self.stateQueue = DispatchQueue(label: "Moqintosh.StreamSender")
        self.previousObjectID = nil
    }

    public func send(objectID: UInt64, content: Content) async throws {
        try await send(objectID: objectID, endOfGroup: false, extensions: [], content: content)
    }

    public func send(objectID: UInt64, endOfGroup: Bool, content: Content) async throws {
        try await send(objectID: objectID, endOfGroup: endOfGroup, extensions: [], content: content)
    }

    func send(
        objectID: UInt64,
        endOfGroup: Bool,
        extensions: [KeyValuePair],
        content: Content
    ) async throws {
        let subgroupObject: SubgroupObject = stateQueue.sync {
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
