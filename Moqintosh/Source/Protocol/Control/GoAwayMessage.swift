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
        var payload: Data = .init()
        if let newSessionURI {
            payload.writeString(newSessionURI)
        }

        var message: Data = .init()
        message.writeVarint(Self.type.rawValue)
        let length: UInt16 = .init(payload.count)
        message.append(UInt8(length >> 8))
        message.append(UInt8(length & 0xFF))
        message.append(payload)
        return message
    }

    static func decode(from payload: Data) throws -> GoAwayMessage {
        guard !payload.isEmpty else {
            return .init(newSessionURI: nil)
        }
        let reader: ByteReader = .init(data: payload)
        let newSessionURI: String = try reader.readString()
        return .init(newSessionURI: newSessionURI)
    }
}
