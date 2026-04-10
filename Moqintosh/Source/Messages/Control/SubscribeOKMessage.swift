//
//  SubscribeOKMessage.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

struct SubscribeOKMessage {

    static let type: MessageType = .subscribeOK

    let requestID: UInt64
    let trackAlias: UInt64
    let expires: UInt64
    let groupOrder: GroupOrder
    let contentExists: Bool
    let largestLocation: Location?
    let parameters: [SetupParameter]

    func encode() -> Data {
        var payload: Data = .init()
        payload.writeVarint(requestID)
        payload.writeVarint(trackAlias)
        payload.writeVarint(expires)
        payload.append(groupOrder.rawValue)
        payload.append(contentExists ? 1 : 0)
        if let largestLocation {
            payload.append(largestLocation.encode())
        }
        payload.writeVarint(UInt64(parameters.count))
        for parameter in parameters {
            payload.append(parameter.encode())
        }

        var message: Data = .init()
        message.writeVarint(Self.type.rawValue)
        let length: UInt16 = .init(payload.count)
        message.append(UInt8(length >> 8))
        message.append(UInt8(length & 0xFF))
        message.append(payload)
        return message
    }

    static func decode(from payload: Data) throws -> SubscribeOKMessage {
        let reader: ByteReader = .init(data: payload)
        let requestID: UInt64 = try reader.readVarint()
        let trackAlias: UInt64 = try reader.readVarint()
        let expires: UInt64 = try reader.readVarint()
        let groupOrder: GroupOrder = try GroupOrder(rawValue: reader.readUInt8Value()) ?? {
            throw SubscribeOKMessageError.invalidGroupOrder
        }()
        let contentExistsValue: UInt8 = try reader.readUInt8Value()
        guard contentExistsValue <= 1 else {
            throw SubscribeOKMessageError.invalidContentExists
        }
        let largestLocation: Location? = contentExistsValue == 1 ? try .decode(from: reader) : nil
        let paramCount: Int = .init(try reader.readVarint())
        var parameters: [SetupParameter] = []
        for _ in 0 ..< paramCount {
            if let parameter: SetupParameter = try? SetupParameter.decode(from: reader) {
                parameters.append(parameter)
            }
        }
        return .init(
            requestID: requestID,
            trackAlias: trackAlias,
            expires: expires,
            groupOrder: groupOrder,
            contentExists: contentExistsValue == 1,
            largestLocation: largestLocation,
            parameters: parameters
        )
    }
}

enum SubscribeOKMessageError: Error {
    case invalidContentExists
    case invalidGroupOrder
}
