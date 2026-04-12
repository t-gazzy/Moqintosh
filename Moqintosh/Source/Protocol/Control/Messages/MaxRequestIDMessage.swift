//
//  MaxRequestIDMessage.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

struct MaxRequestIDMessage {

    static let type: MessageType = .maxRequestID

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

    static func decode(from payload: Data) throws -> MaxRequestIDMessage {
        let reader: ByteReader = ByteReader(data: payload)
        let requestID: UInt64 = try reader.readVarint()
        return MaxRequestIDMessage(requestID: requestID)
    }
}
