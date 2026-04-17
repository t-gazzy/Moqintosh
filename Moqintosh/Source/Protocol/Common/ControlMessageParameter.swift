//
//  ControlMessageParameter.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

enum ControlMessageParameter {
    case authorizationToken(AuthorizationToken)
    case deliveryTimeout(UInt64)
    case maxCacheDuration(UInt64)

    func encode() -> Data {
        keyValuePair.encode()
    }

    static func decode(from reader: ByteReader) throws -> ControlMessageParameter {
        let pair: KeyValuePair = try .decode(from: reader)
        switch pair.type {
        case 0x02:
            guard case .varint(let value) = pair.value else {
                throw ControlMessageParameterError.typeMismatch(type: pair.type)
            }
            return .deliveryTimeout(value)
        case 0x03:
            guard case .bytes(let bytes) = pair.value else {
                throw ControlMessageParameterError.typeMismatch(type: pair.type)
            }
            return .authorizationToken(AuthorizationToken(readOnlyBytes: bytes))
        case 0x04:
            guard case .varint(let value) = pair.value else {
                throw ControlMessageParameterError.typeMismatch(type: pair.type)
            }
            return .maxCacheDuration(value)
        default:
            throw ControlMessageParameterError.unknown(type: pair.type)
        }
    }

    private var keyValuePair: KeyValuePair {
        switch self {
        case .authorizationToken(let token):
            return KeyValuePair(type: 0x03, value: .bytes(ReadOnlyBytes(token.value)))
        case .deliveryTimeout(let value):
            return KeyValuePair(type: 0x02, value: .varint(value))
        case .maxCacheDuration(let value):
            return KeyValuePair(type: 0x04, value: .varint(value))
        }
    }
}

enum ControlMessageParameterError: Error {
    case typeMismatch(type: UInt64)
    case unknown(type: UInt64)
}
