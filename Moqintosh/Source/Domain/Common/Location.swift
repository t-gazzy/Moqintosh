//
//  Location.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Identifies an object within a track.
public struct Location: Sendable {

    /// The group identifier.
    public let group: UInt64
    /// The object identifier within the group.
    public let object: UInt64

    /// Creates a track location.
    public init(group: UInt64, object: UInt64) {
        self.group = group
        self.object = object
    }

    /// Encodes the location using MOQT varints.
    public func encode() -> Data {
        var data: Data = Data()
        data.writeVarint(group)
        data.writeVarint(object)
        return data
    }

    static func decode(from reader: ByteReader) throws -> Location {
        let group: UInt64 = try reader.readVarint()
        let object: UInt64 = try reader.readVarint()
        return Location(group: group, object: object)
    }
}
