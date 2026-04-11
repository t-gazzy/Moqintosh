//
//  PublishDoneMessage.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

struct PublishDoneMessage {

    static let type: MessageType = .publishDone

    let requestID: UInt64
    let statusCode: UInt64
    let streamCount: UInt64
    let reasonPhrase: String

    func encode() -> Data {
        var payload: Data = Data()
        payload.writeVarint(requestID)
        payload.writeVarint(statusCode)
        payload.writeVarint(streamCount)
        payload.writeString(reasonPhrase)

        var message: Data = Data()
        message.writeVarint(Self.type.rawValue)
        let length: UInt16 = UInt16(payload.count)
        message.append(UInt8(length >> 8))
        message.append(UInt8(length & 0xFF))
        message.append(payload)
        return message
    }

    static func decode(from payload: Data) throws -> PublishDoneMessage {
        let reader: ByteReader = ByteReader(data: payload)
        let requestID: UInt64 = try reader.readVarint()
        let statusCode: UInt64 = try reader.readVarint()
        let streamCount: UInt64 = try reader.readVarint()
        let reasonPhrase: String = try reader.readString()
        return PublishDoneMessage(
            requestID: requestID,
            statusCode: statusCode,
            streamCount: streamCount,
            reasonPhrase: reasonPhrase
        )
    }
}
