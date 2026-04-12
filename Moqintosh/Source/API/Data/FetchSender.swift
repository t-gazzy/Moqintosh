//
//  FetchSender.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

/// Sends subgroup objects on a fetch stream.
public final class FetchSender {

    /// The payload or terminal status carried by a fetch object.
    public enum Content {
        case payload(Data)
        case status(UInt64)
    }

    private let stream: TransportUniSendStream

    init(stream: TransportUniSendStream, requestID: UInt64) async throws {
        self.stream = stream
        try await stream.send(bytes: FetchHeader(requestID: requestID).encode(), endOfStream: false)
    }

    /// Sends a fetch object and keeps the stream open.
    public func send(
        groupID: UInt64,
        subgroupID: UInt64,
        objectID: UInt64,
        publisherPriority: UInt8,
        content: Content
    ) async throws {
        try await send(
            groupID: groupID,
            subgroupID: subgroupID,
            objectID: objectID,
            publisherPriority: publisherPriority,
            extensions: [],
            endOfFetch: false,
            content: content
        )
    }

    /// Sends a fetch object and optionally closes the fetch stream.
    public func send(
        groupID: UInt64,
        subgroupID: UInt64,
        objectID: UInt64,
        publisherPriority: UInt8,
        endOfFetch: Bool,
        content: Content
    ) async throws {
        try await send(
            groupID: groupID,
            subgroupID: subgroupID,
            objectID: objectID,
            publisherPriority: publisherPriority,
            extensions: [],
            endOfFetch: endOfFetch,
            content: content
        )
    }

    func send(
        groupID: UInt64,
        subgroupID: UInt64,
        objectID: UInt64,
        publisherPriority: UInt8,
        extensions: [KeyValuePair],
        endOfFetch: Bool,
        content: Content
    ) async throws {
        var data: Data = Data()
        data.writeVarint(groupID)
        data.writeVarint(subgroupID)
        data.writeVarint(objectID)
        data.append(publisherPriority)
        let encodedExtensions: Data = encodeExtensions(extensions)
        data.writeVarint(UInt64(encodedExtensions.count))
        data.append(encodedExtensions)
        switch content {
        case .payload(let payload):
            data.writeVarint(UInt64(payload.count))
            data.append(payload)
        case .status(let status):
            data.writeVarint(0)
            data.writeVarint(status)
        }
        try await stream.send(bytes: data, endOfStream: endOfFetch)
    }

    private func encodeExtensions(_ extensions: [KeyValuePair]) -> Data {
        var data: Data = Data()
        for header in extensions {
            data.append(header.encode())
        }
        return data
    }
}
