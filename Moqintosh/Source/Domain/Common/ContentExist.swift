//
//  ContentExist.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Represents whether a track has published content and its largest location.
public enum ContentExist: Sendable {
    case noContent
    case exists(Location)

    /// Encodes the content-exists value using the MOQT wire format.
    public func encode() -> Data {
        var data: Data = Data()
        switch self {
        case .noContent:
            data.append(0)
        case .exists(let location):
            data.append(1)
            data.append(location.encode())
        }
        return data
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
