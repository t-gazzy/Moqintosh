//
//  PublishNamespaceDoneMessage.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

struct PublishNamespaceDoneMessage {

    static let type: MessageType = .publishNamespaceDone

    let trackNamespace: TrackNamespace

    func encode() -> Data {
        var payload: Data = Data()
        payload.append(trackNamespace.encode())

        var message: Data = Data()
        message.writeVarint(Self.type.rawValue)
        let length: UInt16 = UInt16(payload.count)
        message.append(UInt8(length >> 8))
        message.append(UInt8(length & 0xFF))
        message.append(payload)
        return message
    }

    static func decode(from payload: Data) throws -> PublishNamespaceDoneMessage {
        let reader: ByteReader = ByteReader(data: payload)
        let trackNamespace: TrackNamespace = try .decode(from: reader)
        return PublishNamespaceDoneMessage(trackNamespace: trackNamespace)
    }
}
