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

    /// MAX_AUTH_TOKEN_CACHE_SIZE parameter (Type 0x04, even → varint)
    case maxAuthTokenCacheSize(UInt64)

    /// AUTHORIZATION TOKEN parameter (Type 0x03, odd → bytes)
    case authorizationToken(AuthorizationToken)

    /// AUTHORITY parameter (Type 0x05, odd → bytes)
    case authority(String)

    /// MOQT_IMPLEMENTATION parameter (Type 0x07, odd → bytes)
    /// This is a debug-only extension and not part of the draft.
    case moqtImplementation(String)

    // MARK: - Encode

    func encode() -> Data {
        keyValuePair.encode()
    }

    // MARK: - Decode

    static func decode(from reader: ByteReader) throws -> SetupParameter {
        let pair: KeyValuePair = try .decode(from: reader)
        switch pair.type {
        case 0x01:
            guard case .bytes(let bytes) = pair.value,
                  let string = bytes.utf8String else {
                throw ByteReaderError.invalidUTF8
            }
            return .path(string)
        case 0x02:
            guard case .varint(let value) = pair.value else {
                throw SetupParameterError.typeMismatch(type: pair.type)
            }
            return .maxRequestId(value)
        case 0x03:
            guard case .bytes(let bytes) = pair.value else {
                throw SetupParameterError.typeMismatch(type: pair.type)
            }
            return .authorizationToken(AuthorizationToken(readOnlyBytes: bytes))
        case 0x04:
            guard case .varint(let value) = pair.value else {
                throw SetupParameterError.typeMismatch(type: pair.type)
            }
            return .maxAuthTokenCacheSize(value)
        case 0x05:
            guard case .bytes(let bytes) = pair.value,
                  let string = bytes.utf8String else {
                throw ByteReaderError.invalidUTF8
            }
            return .authority(string)
        case 0x07:
            guard case .bytes(let bytes) = pair.value,
                  let string = bytes.utf8String else {
                throw ByteReaderError.invalidUTF8
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
            return KeyValuePair(type: 0x01, value: .bytes(ReadOnlyBytes(Data(s.utf8))))
        case .maxRequestId(let v):
            return KeyValuePair(type: 0x02, value: .varint(v))
        case .maxAuthTokenCacheSize(let v):
            return KeyValuePair(type: 0x04, value: .varint(v))
        case .authorizationToken(let token):
            return KeyValuePair(type: 0x03, value: .bytes(ReadOnlyBytes(token.value)))
        case .authority(let s):
            return KeyValuePair(type: 0x05, value: .bytes(ReadOnlyBytes(Data(s.utf8))))
        case .moqtImplementation(let s):
            return KeyValuePair(type: 0x07, value: .bytes(ReadOnlyBytes(Data(s.utf8))))
        }
    }
}

enum SetupParameterError: Error {
    case unknown(type: UInt64)
    case typeMismatch(type: UInt64)
}
