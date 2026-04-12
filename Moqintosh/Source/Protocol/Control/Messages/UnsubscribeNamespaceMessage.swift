//
//  UnsubscribeNamespaceMessage.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

struct UnsubscribeNamespaceMessage {

    static let type: MessageType = .unsubscribeNamespace

    let namespacePrefix: TrackNamespace

    func encode() -> Data {
        var payload: Data = Data()
        payload.append(namespacePrefix.encode())

        var message: Data = Data()
        message.writeVarint(Self.type.rawValue)
        let length: UInt16 = UInt16(payload.count)
        message.append(UInt8(length >> 8))
        message.append(UInt8(length & 0xFF))
        message.append(payload)
        return message
    }

    static func decode(from payload: Data) throws -> UnsubscribeNamespaceMessage {
        let reader: ByteReader = ByteReader(data: payload)
        let namespacePrefix: TrackNamespace = try .decode(from: reader)
        return UnsubscribeNamespaceMessage(namespacePrefix: namespacePrefix)
    }
}
