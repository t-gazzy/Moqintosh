//
//  PublishErrorMessage.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

struct PublishErrorMessage {

    static let type: MessageType = .publishError

    let requestID: UInt64
    let errorCode: UInt64
    let reasonPhrase: String

    func encode() -> Data {
        var payload: Data = Data()
        payload.writeVarint(requestID)
        payload.writeVarint(errorCode)
        payload.writeString(reasonPhrase)

        var message: Data = Data()
        message.writeVarint(Self.type.rawValue)
        let length: UInt16 = UInt16(payload.count)
        message.append(UInt8(length >> 8))
        message.append(UInt8(length & 0xFF))
        message.append(payload)
        return message
    }

    static func decode(from payload: Data) throws -> PublishErrorMessage {
        let reader: ByteReader = ByteReader(data: payload)
        let requestID: UInt64 = try reader.readVarint()
        let errorCode: UInt64 = try reader.readVarint()
        let reasonPhrase: String = try reader.readString()
        return PublishErrorMessage(requestID: requestID, errorCode: errorCode, reasonPhrase: reasonPhrase)
    }
}
