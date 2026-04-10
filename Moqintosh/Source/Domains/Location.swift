//
//  Location.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Identifies an object within a track.
public struct Location {

    public let group: UInt64
    public let object: UInt64

    public init(group: UInt64, object: UInt64) {
        self.group = group
        self.object = object
    }

    func encode() -> Data {
        var data: Data = .init()
        data.writeVarint(group)
        data.writeVarint(object)
        return data
    }

    static func decode(from reader: ByteReader) throws -> Location {
        let group: UInt64 = try reader.readVarint()
        let object: UInt64 = try reader.readVarint()
        return .init(group: group, object: object)
    }
}
