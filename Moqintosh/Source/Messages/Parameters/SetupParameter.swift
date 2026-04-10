//
//  SetupParameter.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// MOQT Setup Parameters (Section 9.3.2)
///
/// Uses the Key-Value-Pair format. Odd types carry byte sequences; even types carry varints.
enum SetupParameter {

    /// PATH parameter (Type 0x01, odd → bytes)
    case path(String)

    /// MAX_REQUEST_ID parameter (Type 0x02, even → varint)
    case maxRequestId(UInt64)

    /// AUTHORITY parameter (Type 0x05, odd → bytes)
    case authority(String)

    /// MOQT_IMPLEMENTATION parameter (Type 0x06, even → bytes)
    /// Note: Type 0x06 is even but carries a UTF-8 string; encoded as length-prefixed bytes
    /// per the Key-Value-Pair spec (odd type). Draft-14 Section 9.3.2.6.
    case moqtImplementation(String)

    // MARK: - Encode

    func encode() -> Data {
        keyValuePair.encode()
    }

    // MARK: - Decode

    static func decode(from data: Data, at offset: inout Int) throws -> SetupParameter {
        let pair = try KeyValuePair.decode(from: data, at: &offset)
        switch pair.type {
        case 0x01:
            guard case .bytes(let bytes) = pair.value,
                  let string = String(bytes: bytes, encoding: .utf8) else {
                throw DataReadError.invalidUTF8
            }
            return .path(string)
        case 0x02:
            guard case .varint(let v) = pair.value else {
                throw SetupParameterError.typeMismatch(type: pair.type)
            }
            return .maxRequestId(v)
        case 0x05:
            guard case .bytes(let bytes) = pair.value,
                  let string = String(bytes: bytes, encoding: .utf8) else {
                throw DataReadError.invalidUTF8
            }
            return .authority(string)
        case 0x07:
            guard case .bytes(let bytes) = pair.value,
                  let string = String(bytes: bytes, encoding: .utf8) else {
                throw DataReadError.invalidUTF8
            }
            return .moqtImplementation(string)
        default:
            throw SetupParameterError.unknown(type: pair.type)
        }
    }

    // MARK: - Private

    private var keyValuePair: KeyValuePair {
        switch self {
        case .path(let s):
            return KeyValuePair(type: 0x01, value: .bytes(Data(s.utf8)))
        case .maxRequestId(let v):
            return KeyValuePair(type: 0x02, value: .varint(v))
        case .authority(let s):
            return KeyValuePair(type: 0x05, value: .bytes(Data(s.utf8)))
        case .moqtImplementation(let s):
            return KeyValuePair(type: 0x07, value: .bytes(Data(s.utf8)))
        }
    }
}

enum SetupParameterError: Error {
    case unknown(type: UInt64)
    case typeMismatch(type: UInt64)
}
