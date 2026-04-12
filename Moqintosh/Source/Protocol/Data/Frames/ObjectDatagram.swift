//
//  ObjectDatagram.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

public struct ObjectDatagram: Sendable {

    public enum ObjectID: Sendable {
        case none
        case explicit(UInt64)
    }

    public enum Content: Sendable {
        case payload(Data)
        case status(UInt64)
    }

    enum DatagramType: UInt64 {
        case object = 0x00
        case objectWithExtensions = 0x01
        case endOfGroupObject = 0x02
        case endOfGroupObjectWithExtensions = 0x03
        case objectWithoutID = 0x04
        case objectWithoutIDWithExtensions = 0x05
        case endOfGroupObjectWithoutID = 0x06
        case endOfGroupObjectWithoutIDWithExtensions = 0x07
        case status = 0x20
        case statusWithExtensions = 0x21

        enum ContentKind {
            case payload
            case status
        }

        var endOfGroup: Bool {
            switch self {
            case .endOfGroupObject, .endOfGroupObjectWithExtensions, .endOfGroupObjectWithoutID, .endOfGroupObjectWithoutIDWithExtensions:
                return true
            default:
                return false
            }
        }

        var extensionsPresent: Bool {
            switch self {
            case .objectWithExtensions, .endOfGroupObjectWithExtensions, .objectWithoutIDWithExtensions, .endOfGroupObjectWithoutIDWithExtensions, .statusWithExtensions:
                return true
            default:
                return false
            }
        }

        var objectIDPresent: Bool {
            switch self {
            case .objectWithoutID, .objectWithoutIDWithExtensions, .endOfGroupObjectWithoutID, .endOfGroupObjectWithoutIDWithExtensions:
                return false
            default:
                return true
            }
        }

        var contentKind: ContentKind {
            switch self {
            case .status, .statusWithExtensions:
                return .status
            default:
                return .payload
            }
        }
    }

    public let trackAlias: UInt64
    public let groupID: UInt64
    public let objectID: ObjectID
    public let publisherPriority: UInt8
    let extensions: [KeyValuePair]
    public let endOfGroup: Bool
    public let content: Content

    public init(
        trackAlias: UInt64,
        groupID: UInt64,
        objectID: ObjectID,
        publisherPriority: UInt8,
        endOfGroup: Bool = false,
        content: Content
    ) {
        self.init(
            trackAlias: trackAlias,
            groupID: groupID,
            objectID: objectID,
            publisherPriority: publisherPriority,
            extensions: [],
            endOfGroup: endOfGroup,
            content: content
        )
    }

    init(
        trackAlias: UInt64,
        groupID: UInt64,
        objectID: ObjectID,
        publisherPriority: UInt8,
        extensions: [KeyValuePair] = [],
        endOfGroup: Bool = false,
        content: Content
    ) {
        self.trackAlias = trackAlias
        self.groupID = groupID
        self.objectID = objectID
        self.publisherPriority = publisherPriority
        self.extensions = extensions
        self.endOfGroup = endOfGroup
        self.content = content
    }

    public func encode() -> Data {
        let datagramType: DatagramType = resolvedType()
        var data: Data = Data()
        data.writeVarint(datagramType.rawValue)
        data.writeVarint(trackAlias)
        data.writeVarint(groupID)
        switch objectID {
        case .none:
            break
        case .explicit(let objectID):
            data.writeVarint(objectID)
        }
        data.append(publisherPriority)
        if !extensions.isEmpty {
            let encodedExtensions: Data = encodeExtensions(extensions)
            data.writeVarint(UInt64(encodedExtensions.count))
            data.append(encodedExtensions)
        }
        switch content {
        case .payload(let payload):
            data.append(payload)
        case .status(let status):
            data.writeVarint(status)
        }
        return data
    }

    public static func decode(_ data: Data) throws -> ObjectDatagram {
        let reader: ByteReader = ByteReader(data: data)
        let datagramTypeRawValue: UInt64 = try reader.readVarint()
        guard let datagramType: DatagramType = DatagramType(rawValue: datagramTypeRawValue) else {
            throw ObjectDatagramError.invalidType(datagramTypeRawValue)
        }
        let trackAlias: UInt64 = try reader.readVarint()
        let groupID: UInt64 = try reader.readVarint()
        let objectID: ObjectID = datagramType.objectIDPresent
            ? .explicit(try reader.readVarint())
            : .none
        let publisherPriority: UInt8 = try reader.readUInt8Value()
        let extensions: [KeyValuePair]
        if datagramType.extensionsPresent {
            let encodedExtensionsLength: Int = Int(try reader.readVarint())
            guard encodedExtensionsLength > 0 else {
                throw ObjectDatagramError.invalidExtensionHeadersLength
            }
            let encodedExtensions: Data = try reader.readBytes(length: encodedExtensionsLength)
            extensions = try decodeExtensions(from: encodedExtensions)
        } else {
            extensions = []
        }
        let content: Content
        switch datagramType.contentKind {
        case .payload:
            content = .payload(try reader.readBytes(length: reader.remainingCount))
        case .status:
            content = .status(try reader.readVarint())
        }
        return ObjectDatagram(
            trackAlias: trackAlias,
            groupID: groupID,
            objectID: objectID,
            publisherPriority: publisherPriority,
            extensions: extensions,
            endOfGroup: datagramType.endOfGroup,
            content: content
        )
    }

    private func resolvedType() -> DatagramType {
        switch (endOfGroup, !extensions.isEmpty, objectID, content) {
        case (false, false, .explicit, .payload):
            return .object
        case (false, true, .explicit, .payload):
            return .objectWithExtensions
        case (true, false, .explicit, .payload):
            return .endOfGroupObject
        case (true, true, .explicit, .payload):
            return .endOfGroupObjectWithExtensions
        case (false, false, .none, .payload):
            return .objectWithoutID
        case (false, true, .none, .payload):
            return .objectWithoutIDWithExtensions
        case (true, false, .none, .payload):
            return .endOfGroupObjectWithoutID
        case (true, true, .none, .payload):
            return .endOfGroupObjectWithoutIDWithExtensions
        case (false, false, .explicit, .status):
            return .status
        case (false, true, .explicit, .status):
            return .statusWithExtensions
        case (true, _, _, .status):
            preconditionFailure("Status datagrams cannot mark end of group")
        case (_, _, .none, .status):
            preconditionFailure("Status datagrams require an explicit object ID")
        }
    }

    private func encodeExtensions(_ extensions: [KeyValuePair]) -> Data {
        var data: Data = Data()
        for header in extensions {
            data.append(header.encode())
        }
        return data
    }

    private static func decodeExtensions(from data: Data) throws -> [KeyValuePair] {
        let reader: ByteReader = ByteReader(data: data)
        var extensions: [KeyValuePair] = []
        while reader.remainingCount > 0 {
            extensions.append(try .decode(from: reader))
        }
        return extensions
    }
}

enum ObjectDatagramError: Error {
    case invalidType(UInt64)
    case invalidExtensionHeadersLength
}
