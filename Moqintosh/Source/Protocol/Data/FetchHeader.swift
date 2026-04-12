//
//  FetchHeader.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

struct FetchHeader: Sendable {

    static let type: UInt64 = 0x05

    let requestID: UInt64

    func encode() -> Data {
        var data: Data = Data()
        data.writeVarint(Self.type)
        data.writeVarint(requestID)
        return data
    }

    static func decode(from reader: ByteReader) throws -> FetchHeader {
        let type: UInt64 = try reader.readVarint()
        guard type == Self.type else {
            throw FetchHeaderError.invalidType(type)
        }
        let requestID: UInt64 = try reader.readVarint()
        return FetchHeader(requestID: requestID)
    }
}

enum FetchHeaderError: Error {
    case invalidType(UInt64)
}
