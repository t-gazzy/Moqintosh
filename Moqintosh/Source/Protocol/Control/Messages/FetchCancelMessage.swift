//
//  FetchCancelMessage.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

struct FetchCancelMessage {

    static let type: MessageType = .fetchCancel

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

    static func decode(from payload: Data) throws -> FetchCancelMessage {
        let reader: ByteReader = ByteReader(data: payload)
        let requestID: UInt64 = try reader.readVarint()
        return FetchCancelMessage(requestID: requestID)
    }
}
