//
//  GoAwayMessage.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

struct GoAwayMessage {

    static let type: MessageType = .goaway

    let newSessionURI: String?

    func encode() -> Data {
        var payload: Data = Data()
        if let newSessionURI {
            payload.writeString(newSessionURI)
        }

        var message: Data = Data()
        message.writeVarint(Self.type.rawValue)
        let length: UInt16 = UInt16(payload.count)
        message.append(UInt8(length >> 8))
        message.append(UInt8(length & 0xFF))
        message.append(payload)
        return message
    }

    static func decode(from payload: Data) throws -> GoAwayMessage {
        guard !payload.isEmpty else {
            return GoAwayMessage(newSessionURI: nil)
        }
        let reader: ByteReader = ByteReader(data: payload)
        let newSessionURI: String = try reader.readString()
        return GoAwayMessage(newSessionURI: newSessionURI)
    }
}
