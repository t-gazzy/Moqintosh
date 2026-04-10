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
struct KeyValuePair {

    enum Value {
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

    static func decode(from data: Data, at offset: inout Int) throws -> KeyValuePair {
        let type: Int = try data.readVarint(at: &offset)
        let value: Value
        if type % 2 == 0 {
            // Even: varint value
            let v: Int = try data.readVarint(at: &offset)
            value = .varint(UInt64(v))
        } else {
            // Odd: length-prefixed byte sequence
            let length: Int = try data.readVarint(at: &offset)
            guard offset + length <= data.count else {
                throw DataReadError.insufficientData(requested: length, available: data.count - offset)
            }
            let bytes = data[data.startIndex + offset ..< data.startIndex + offset + length]
            offset += length
            value = .bytes(Data(bytes))
        }
        return KeyValuePair(type: UInt64(type), value: value)
    }
}
