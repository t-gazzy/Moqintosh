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
        var payload: Data = .init()
        payload.writeVarint(requestID)

        var message: Data = .init()
        message.writeVarint(Self.type.rawValue)
        let length: UInt16 = .init(payload.count)
        message.append(UInt8(length >> 8))
        message.append(UInt8(length & 0xFF))
        message.append(payload)
        return message
    }

    static func decode(from payload: Data) throws -> FetchCancelMessage {
        let reader: ByteReader = .init(data: payload)
        let requestID: UInt64 = try reader.readVarint()
        return .init(requestID: requestID)
    }
}
