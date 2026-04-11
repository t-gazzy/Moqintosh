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
        var payload: Data = .init()
        payload.append(trackNamespace.encode())

        var message: Data = .init()
        message.writeVarint(Self.type.rawValue)
        let length: UInt16 = .init(payload.count)
        message.append(UInt8(length >> 8))
        message.append(UInt8(length & 0xFF))
        message.append(payload)
        return message
    }

    static func decode(from payload: Data) throws -> PublishNamespaceDoneMessage {
        let reader: ByteReader = .init(data: payload)
        let trackNamespace: TrackNamespace = try .decode(from: reader)
        return .init(trackNamespace: trackNamespace)
    }
}
