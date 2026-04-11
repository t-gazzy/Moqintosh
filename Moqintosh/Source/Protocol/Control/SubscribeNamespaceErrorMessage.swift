//
//  SubscribeNamespaceErrorMessage.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// MOQT SUBSCRIBE_NAMESPACE_ERROR message (Section 9.30, Type = 0x13)
///
/// Wire format:
/// ```
/// SUBSCRIBE_NAMESPACE_ERROR {
///   Type (i) = 0x13,
///   Length (16),
///   Request ID (i),
///   Error Code (i),
///   Reason Phrase Length (i),
///   Reason Phrase Value (..),
/// }
/// ```
struct SubscribeNamespaceErrorMessage {

    static let type: MessageType = .subscribeNamespaceError

    let requestID: UInt64
    let errorCode: UInt64
    let reasonPhrase: String

    func encode() -> Data {
        var payload: Data = .init()
        payload.writeVarint(requestID)
        payload.writeVarint(errorCode)
        payload.writeString(reasonPhrase)

        var message: Data = .init()
        message.writeVarint(Self.type.rawValue)
        let length: UInt16 = .init(payload.count)
        message.append(UInt8(length >> 8))
        message.append(UInt8(length & 0xFF))
        message.append(payload)
        return message
    }

    // MARK: - Decode

    static func decode(from payload: Data) throws -> SubscribeNamespaceErrorMessage {
        let reader = ByteReader(data: payload)
        let requestID = try reader.readVarint()
        let errorCode = try reader.readVarint()
        let reasonPhrase = try reader.readString()
        return SubscribeNamespaceErrorMessage(requestID: requestID, errorCode: errorCode, reasonPhrase: reasonPhrase)
    }
}
