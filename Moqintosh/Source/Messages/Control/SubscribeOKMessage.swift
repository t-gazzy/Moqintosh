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
    let contentExist: ContentExist
    let deliveryTimeout: UInt64?
    let maxCacheDuration: UInt64?

    func encode() -> Data {
        var payload: Data = .init()
        payload.writeVarint(requestID)
        payload.writeVarint(trackAlias)
        payload.writeVarint(expires)
        payload.append(groupOrder.rawValue)
        payload.append(contentExist.flag)
        if let largestLocation: Location = contentExist.largestLocation {
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
        let contentExist: ContentExist = try .decode(from: reader)
        let paramCount: Int = .init(try reader.readVarint())
        var deliveryTimeout: UInt64?
        var maxCacheDuration: UInt64?
        for _ in 0 ..< paramCount {
            switch try? ControlMessageParameter.decode(from: reader) {
            case .deliveryTimeout(let value):
                deliveryTimeout = value
            case .maxCacheDuration(let value):
                maxCacheDuration = value
            default:
                break
            }
        }
        return .init(
            requestID: requestID,
            trackAlias: trackAlias,
            expires: expires,
            groupOrder: groupOrder,
            contentExist: contentExist,
            deliveryTimeout: deliveryTimeout,
            maxCacheDuration: maxCacheDuration
        )
    }

    private var parameters: [ControlMessageParameter] {
        var parameters: [ControlMessageParameter] = []
        if let deliveryTimeout {
            parameters.append(.deliveryTimeout(deliveryTimeout))
        }
        if let maxCacheDuration {
            parameters.append(.maxCacheDuration(maxCacheDuration))
        }
        return parameters
    }
}

enum SubscribeOKMessageError: Error {
    case invalidGroupOrder
}
