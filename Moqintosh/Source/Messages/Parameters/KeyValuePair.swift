//
//  KeyValuePair.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// MOQT Key-Value-Pair (Section 1.4.2)
///
/// - Even type: Value is a single varint (no Length field)
/// - Odd type:  Value is a byte sequence preceded by a Length varint
struct KeyValuePair: Sendable {

    enum Value: Sendable {
        case varint(UInt64)
        case bytes(Data)
    }

    let type: UInt64
    let value: Value

    // MARK: - Encode

    func encode() -> Data {
        var data = Data()
        data.writeVarint(type)
        switch value {
        case .varint(let v):
            data.writeVarint(v)
        case .bytes(let bytes):
            data.writeVarint(UInt64(bytes.count))
            data.append(bytes)
        }
        return data
    }

    // MARK: - Decode

    static func decode(from reader: ByteReader) throws -> KeyValuePair {
        let type: UInt64 = try reader.readVarint()
        let value: Value
        if type % 2 == 0 {
            // Even: varint value
            value = .varint(try reader.readVarint())
        } else {
            // Odd: length-prefixed byte sequence
            let length = Int(try reader.readVarint())
            value = .bytes(try reader.readBytes(length: length))
        }
        return KeyValuePair(type: type, value: value)
    }
}
