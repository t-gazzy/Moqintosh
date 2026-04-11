//
//  PublishOKMessage.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

struct PublishOKMessage {

    static let type: MessageType = .publishOK

    let requestID: UInt64
    let forward: Bool
    let subscriberPriority: UInt8
    let groupOrder: GroupOrder
    let filter: SubscriptionFilter
    let deliveryTimeout: UInt64?

    func encode() -> Data {
        var payload: Data = .init()
        payload.writeVarint(requestID)
        payload.append(forward ? 1 : 0)
        payload.append(subscriberPriority)
        payload.append(groupOrder.rawValue)
        payload.append(filter.encode())
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

    static func decode(from payload: Data) throws -> PublishOKMessage {
        let reader: ByteReader = .init(data: payload)
        let requestID: UInt64 = try reader.readVarint()
        let forwardValue: UInt8 = try reader.readUInt8Value()
        guard forwardValue <= 1 else {
            throw PublishOKMessageError.invalidForward
        }
        let subscriberPriority: UInt8 = try reader.readUInt8Value()
        let groupOrder: GroupOrder = try GroupOrder(rawValue: reader.readUInt8Value()) ?? {
            throw PublishOKMessageError.invalidGroupOrder
        }()
        let filter: SubscriptionFilter = try .decode(from: reader)
        let paramCount: Int = .init(try reader.readVarint())
        var deliveryTimeout: UInt64?
        for _ in 0 ..< paramCount {
            if case .deliveryTimeout(let value) = try? ControlMessageParameter.decode(from: reader) {
                deliveryTimeout = value
            }
        }
        return .init(
            requestID: requestID,
            forward: forwardValue == 1,
            subscriberPriority: subscriberPriority,
            groupOrder: groupOrder,
            filter: filter,
            deliveryTimeout: deliveryTimeout
        )
    }

    private var parameters: [ControlMessageParameter] {
        guard let deliveryTimeout else { return [] }
        return [.deliveryTimeout(deliveryTimeout)]
    }
}

enum PublishOKMessageError: Error {
    case invalidFilterType
    case invalidForward
    case invalidGroupOrder
}
