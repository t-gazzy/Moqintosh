//
//  SubgroupObject.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

public struct SubgroupObject {

    public enum Content {
        case payload(Data)
        case status(UInt64)
    }

    let header: SubgroupHeader
    public let objectID: UInt64
    let previousObjectID: UInt64?
    let extensions: [KeyValuePair]
    public let content: Content

    init(
        header: SubgroupHeader,
        previousObjectID: UInt64?,
        objectID: UInt64,
        extensions: [KeyValuePair],
        content: Content
    ) {
        precondition(header.usesExtensions || extensions.isEmpty, "Subgroup objects cannot include extensions unless the header enables them")
        self.header = header
        self.objectID = objectID
        self.previousObjectID = previousObjectID
        self.extensions = extensions
        self.content = content
    }

    func encode() -> Data {
        var data: Data = .init()
        data.writeVarint(objectIDDelta)
        if header.usesExtensions {
            let encodedExtensions: Data = encodeExtensions(extensions)
            data.writeVarint(UInt64(encodedExtensions.count))
            data.append(encodedExtensions)
        }
        switch content {
        case .payload(let payload):
            data.writeVarint(UInt64(payload.count))
            data.append(payload)
        case .status(let status):
            data.writeVarint(0)
            data.writeVarint(status)
        }
        return data
    }

    static func decode(
        _ data: Data,
        header: SubgroupHeader,
        previousObjectID: UInt64? = nil
    ) throws -> SubgroupObject {
        let reader: ByteReader = .init(data: data)
        return try decode(from: reader, header: header, previousObjectID: previousObjectID)
    }

    static func decode(
        from reader: ByteReader,
        header: SubgroupHeader,
        previousObjectID: UInt64? = nil
    ) throws -> SubgroupObject {
        let objectIDDelta: UInt64 = try reader.readVarint()
        let objectID: UInt64
        if let previousObjectID {
            objectID = previousObjectID + objectIDDelta + 1
        } else {
            objectID = objectIDDelta
        }
        let extensions: [KeyValuePair]
        if header.usesExtensions {
            let encodedExtensionsLength: Int = Int(try reader.readVarint())
            let encodedExtensions: Data = try reader.readBytes(length: encodedExtensionsLength)
            extensions = try decodeExtensions(from: encodedExtensions)
        } else {
            extensions = []
        }
        let payloadLength: Int = Int(try reader.readVarint())
        let content: Content
        if payloadLength == 0 {
            content = .status(try reader.readVarint())
        } else {
            content = .payload(try reader.readBytes(length: payloadLength))
        }
        return .init(
            header: header,
            previousObjectID: previousObjectID,
            objectID: objectID,
            extensions: extensions,
            content: content
        )
    }

    private var objectIDDelta: UInt64 {
        if let previousObjectID {
            precondition(objectID > previousObjectID, "objectID must be greater than previousObjectID")
            return objectID - previousObjectID - 1
        }
        return objectID
    }

    private func encodeExtensions(_ extensions: [KeyValuePair]) -> Data {
        var data: Data = .init()
        for header in extensions {
            data.append(header.encode())
        }
        return data
    }

    private static func decodeExtensions(from data: Data) throws -> [KeyValuePair] {
        let reader: ByteReader = .init(data: data)
        var extensions: [KeyValuePair] = []
        while reader.remainingCount > 0 {
            extensions.append(try .decode(from: reader))
        }
        return extensions
    }
}
