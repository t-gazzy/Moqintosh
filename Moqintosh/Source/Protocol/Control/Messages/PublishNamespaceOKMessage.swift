//
//  PublishNamespaceOKMessage.swift
//  Moqintosh
//
//  Created by Takemasa Kaji on 2026/04/10.
//

import Foundation

/// MOQT PUBLISH_NAMESPACE_OK message (Section 9.24, Type = 0x07)
///
/// Wire format:
/// ```
/// PUBLISH_NAMESPACE_OK {
///   Type (i) = 0x07,
///   Length (16),
///   Request ID (i),
/// }
/// ```
struct PublishNamespaceOKMessage {

    static let type: MessageType = .publishNamespaceOK

    let requestID: UInt64

    func encode() -> Data {
        var payload: Data = Data()
        payload.writeVarint(requestID)

        var message: Data = Data()
        message.writeVarint(Self.type.rawValue)
        let length: UInt16 = UInt16(payload.count)
        message.append(UInt8(length >> 8))
        message.append(UInt8(length & 0xFF))
        message.append(payload)
        return message
    }

    static func decode(from payload: Data) throws -> PublishNamespaceOKMessage {
        let reader: ByteReader = ByteReader(data: payload)
        let requestID: UInt64 = try reader.readVarint()
        return PublishNamespaceOKMessage(requestID: requestID)
    }
}
