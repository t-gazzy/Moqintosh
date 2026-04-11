//
//  SubgroupHeader.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

public struct SubgroupHeader: Sendable {

    public enum SubgroupID: Equatable, Sendable {
        case zero
        case firstObject
        case explicit(UInt64)
    }

    enum HeaderType: UInt64 {
        case subgroupZero = 0x10
        case subgroupZeroWithExtensions = 0x11
        case subgroupFirstObject = 0x12
        case subgroupFirstObjectWithExtensions = 0x13
        case subgroupExplicit = 0x14
        case subgroupExplicitWithExtensions = 0x15
        case endOfGroupSubgroupZero = 0x18
        case endOfGroupSubgroupZeroWithExtensions = 0x19
        case endOfGroupSubgroupFirstObject = 0x1A
        case endOfGroupSubgroupFirstObjectWithExtensions = 0x1B
        case endOfGroupSubgroupExplicit = 0x1C
        case endOfGroupSubgroupExplicitWithExtensions = 0x1D

        var subgroupIDFieldPresent: Bool {
            switch self {
            case .subgroupExplicit, .subgroupExplicitWithExtensions, .endOfGroupSubgroupExplicit, .endOfGroupSubgroupExplicitWithExtensions:
                return true
            default:
                return false
            }
        }

        var implicitSubgroupID: SubgroupHeader.SubgroupID {
            switch self {
            case .subgroupZero, .subgroupZeroWithExtensions, .endOfGroupSubgroupZero, .endOfGroupSubgroupZeroWithExtensions:
                return .zero
            case .subgroupFirstObject, .subgroupFirstObjectWithExtensions, .endOfGroupSubgroupFirstObject, .endOfGroupSubgroupFirstObjectWithExtensions:
                return .firstObject
            case .subgroupExplicit, .subgroupExplicitWithExtensions, .endOfGroupSubgroupExplicit, .endOfGroupSubgroupExplicitWithExtensions:
                preconditionFailure("Explicit subgroup IDs are not implicit")
            }
        }

        var extensionsPresent: Bool {
            switch self {
            case .subgroupZeroWithExtensions, .subgroupFirstObjectWithExtensions, .subgroupExplicitWithExtensions, .endOfGroupSubgroupZeroWithExtensions, .endOfGroupSubgroupFirstObjectWithExtensions, .endOfGroupSubgroupExplicitWithExtensions:
                return true
            default:
                return false
            }
        }

        var containsEndOfGroup: Bool {
            switch self {
            case .endOfGroupSubgroupZero, .endOfGroupSubgroupZeroWithExtensions, .endOfGroupSubgroupFirstObject, .endOfGroupSubgroupFirstObjectWithExtensions, .endOfGroupSubgroupExplicit, .endOfGroupSubgroupExplicitWithExtensions:
                return true
            default:
                return false
            }
        }
    }

    let trackAlias: UInt64
    let groupID: UInt64
    public let subgroupID: SubgroupID
    let publisherPriority: UInt8
    let usesExtensions: Bool
    let containsEndOfGroup: Bool

    init(
        trackAlias: UInt64,
        groupID: UInt64,
        subgroupID: SubgroupID,
        publisherPriority: UInt8,
        usesExtensions: Bool = false,
        containsEndOfGroup: Bool = false
    ) {
        self.trackAlias = trackAlias
        self.groupID = groupID
        self.subgroupID = subgroupID
        self.publisherPriority = publisherPriority
        self.usesExtensions = usesExtensions
        self.containsEndOfGroup = containsEndOfGroup
    }

    func encode() -> Data {
        let headerType: HeaderType = resolvedType()
        var data: Data = .init()
        data.writeVarint(headerType.rawValue)
        data.writeVarint(trackAlias)
        data.writeVarint(groupID)
        if case .explicit(let subgroupID) = subgroupID {
            data.writeVarint(subgroupID)
        }
        data.append(publisherPriority)
        return data
    }

    func makeObject(
        previousObjectID: UInt64? = nil,
        objectID: UInt64,
        extensions: [KeyValuePair] = [],
        content: SubgroupObject.Content
    ) -> SubgroupObject {
        SubgroupObject(
            header: self,
            previousObjectID: previousObjectID,
            objectID: objectID,
            extensions: extensions,
            content: content
        )
    }

    func resolvedSubgroupID(firstObjectID: UInt64? = nil) -> UInt64 {
        switch subgroupID {
        case .zero:
            return 0
        case .firstObject:
            precondition(firstObjectID != nil, "firstObjectID is required when subgroupID is derived from the first object")
            return firstObjectID!
        case .explicit(let subgroupID):
            return subgroupID
        }
    }

    static func decode(_ data: Data) throws -> SubgroupHeader {
        let reader: ByteReader = .init(data: data)
        return try decode(from: reader)
    }

    static func decode(from reader: ByteReader) throws -> SubgroupHeader {
        let typeRawValue: UInt64 = try reader.readVarint()
        guard let headerType: HeaderType = .init(rawValue: typeRawValue) else {
            throw SubgroupHeaderError.invalidType(typeRawValue)
        }
        let trackAlias: UInt64 = try reader.readVarint()
        let groupID: UInt64 = try reader.readVarint()
        let subgroupID: SubgroupID
        if headerType.subgroupIDFieldPresent {
            subgroupID = .explicit(try reader.readVarint())
        } else {
            subgroupID = headerType.implicitSubgroupID
        }
        let publisherPriority: UInt8 = try reader.readUInt8Value()
        return .init(
            trackAlias: trackAlias,
            groupID: groupID,
            subgroupID: subgroupID,
            publisherPriority: publisherPriority,
            usesExtensions: headerType.extensionsPresent,
            containsEndOfGroup: headerType.containsEndOfGroup
        )
    }

    private func resolvedType() -> HeaderType {
        switch (containsEndOfGroup, usesExtensions, subgroupID) {
        case (false, false, .zero):
            return .subgroupZero
        case (false, true, .zero):
            return .subgroupZeroWithExtensions
        case (false, false, .firstObject):
            return .subgroupFirstObject
        case (false, true, .firstObject):
            return .subgroupFirstObjectWithExtensions
        case (false, false, .explicit):
            return .subgroupExplicit
        case (false, true, .explicit):
            return .subgroupExplicitWithExtensions
        case (true, false, .zero):
            return .endOfGroupSubgroupZero
        case (true, true, .zero):
            return .endOfGroupSubgroupZeroWithExtensions
        case (true, false, .firstObject):
            return .endOfGroupSubgroupFirstObject
        case (true, true, .firstObject):
            return .endOfGroupSubgroupFirstObjectWithExtensions
        case (true, false, .explicit):
            return .endOfGroupSubgroupExplicit
        case (true, true, .explicit):
            return .endOfGroupSubgroupExplicitWithExtensions
        }
    }
}

enum SubgroupHeaderError: Error {
    case invalidType(UInt64)
}
