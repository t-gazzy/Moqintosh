//
//  FetchObjectFrameReader.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

final class FetchObjectFrameReader {

    private var buffer: Data
    private var isStreamComplete: Bool

    init(initialData: Data = Data()) {
        self.buffer = initialData
        self.isStreamComplete = false
    }

    func read(from stream: any TransportUniReceiveStream) async throws -> SubgroupObject {
        while true {
            if let object: SubgroupObject = try extractObject() {
                return object
            }
            if isStreamComplete {
                throw StreamReceiveCompletionError.closed
            }
            let result: TransportUniReceiveResult = try await stream.receive()
            buffer.append(result.bytes)
            isStreamComplete = result.isComplete
        }
    }

    private func extractObject() throws -> SubgroupObject? {
        let reader: ByteReader = ByteReader(data: buffer)
        guard let groupID: UInt64 = try? reader.readVarint() else {
            return nil
        }
        guard let subgroupID: UInt64 = try? reader.readVarint() else {
            return nil
        }
        guard let objectID: UInt64 = try? reader.readVarint() else {
            return nil
        }
        guard let publisherPriority: UInt8 = try? reader.readUInt8Value() else {
            return nil
        }
        guard let encodedExtensionsLength: Int = try? .init(reader.readVarint()) else {
            return nil
        }
        guard let encodedExtensions: Data = try? reader.readBytes(length: encodedExtensionsLength) else {
            return nil
        }
        guard let payloadLength: Int = try? .init(reader.readVarint()) else {
            return nil
        }
        let content: SubgroupObject.Content
        if payloadLength == 0 {
            guard let status: UInt64 = try? reader.readVarint() else {
                return nil
            }
            content = .status(status)
        } else {
            guard let payload: ReadOnlyBytes = try? reader.readReadOnlyBytes(length: payloadLength) else {
                return nil
            }
            content = .payload(payload)
        }
        let extensions: [KeyValuePair] = try decodeExtensions(from: encodedExtensions)
        let header: SubgroupHeader = SubgroupHeader(
            trackAlias: 0,
            groupID: groupID,
            subgroupID: .explicit(subgroupID),
            publisherPriority: publisherPriority,
            usesExtensions: true
        )
        let object: SubgroupObject = SubgroupObject(
            header: header,
            previousObjectID: nil,
            objectID: objectID,
            extensions: extensions,
            content: content
        )
        buffer.removeFirst(reader.consumedCount)
        return object
    }

    private func decodeExtensions(from data: Data) throws -> [KeyValuePair] {
        let reader: ByteReader = ByteReader(data: data)
        var extensions: [KeyValuePair] = []
        while reader.remainingCount > 0 {
            extensions.append(try .decode(from: reader))
        }
        return extensions
    }
}
