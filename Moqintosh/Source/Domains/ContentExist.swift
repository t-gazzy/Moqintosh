//
//  ContentExist.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Represents whether a track has published content and its largest location.
public enum ContentExist {
    case noContent
    case exists(Location)

    var flag: UInt8 {
        switch self {
        case .noContent:
            return 0
        case .exists:
            return 1
        }
    }

    var largestLocation: Location? {
        switch self {
        case .noContent:
            return nil
        case .exists(let location):
            return location
        }
    }

    static func decode(from reader: ByteReader) throws -> ContentExist {
        let value: UInt8 = try reader.readUInt8Value()
        switch value {
        case 0:
            return .noContent
        case 1:
            return .exists(try .decode(from: reader))
        default:
            throw ContentExistError.invalidValue(value)
        }
    }
}

enum ContentExistError: Error {
    case invalidValue(UInt8)
}
