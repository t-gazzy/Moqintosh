//
//  PublishNamespaceCancelMessage.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

struct PublishNamespaceCancelMessage {

    static let type: MessageType = .publishNamespaceCancel

    let trackNamespace: TrackNamespace
    let errorCode: UInt64
    let reasonPhrase: String

    func encode() -> Data {
        var payload: Data = Data()
        payload.append(trackNamespace.encode())
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

    static func decode(from payload: Data) throws -> PublishNamespaceCancelMessage {
        let reader: ByteReader = ByteReader(data: payload)
        let trackNamespace: TrackNamespace = try .decode(from: reader)
        let errorCode: UInt64 = try reader.readVarint()
        let reasonPhrase: String = try reader.readString()
        return PublishNamespaceCancelMessage(trackNamespace: trackNamespace, errorCode: errorCode, reasonPhrase: reasonPhrase)
    }
}
