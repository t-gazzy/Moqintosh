//
//  SubscribeMessage.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

struct SubscribeMessage {

    static let type: MessageType = .subscribe

    let requestID: UInt64
    let resource: TrackResource
    let subscriberPriority: UInt8
    let groupOrder: GroupOrder
    let forward: Bool
    let filter: SubscriptionFilter
    let deliveryTimeout: UInt64?

    func encode() -> Data {
        var payload: Data = .init()
        payload.writeVarint(requestID)
        payload.append(resource.trackNamespace.encode())
        payload.writeVarint(UInt64(resource.trackName.count))
        payload.append(resource.trackName)
        payload.append(subscriberPriority)
        payload.append(groupOrder.rawValue)
        payload.append(forward ? 1 : 0)
        payload.append(filterPayload)
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

    static func decode(from payload: Data) throws -> SubscribeMessage {
        let reader: ByteReader = .init(data: payload)
        let requestID: UInt64 = try reader.readVarint()
        let trackNamespace: TrackNamespace = try TrackNamespace.decode(from: reader)
        let trackNameLength: Int = .init(try reader.readVarint())
        let trackName: Data = try reader.readBytes(length: trackNameLength)
        let subscriberPriority: UInt8 = try reader.readUInt8Value()
        let groupOrder: GroupOrder = try GroupOrder(rawValue: reader.readUInt8Value()) ?? {
            throw SubscribeMessageError.invalidGroupOrder
        }()
        let forwardValue: UInt8 = try reader.readUInt8Value()
        guard forwardValue <= 1 else {
            throw SubscribeMessageError.invalidForward
        }
        let filter: SubscriptionFilter = try decodeFilter(from: reader)
        let paramCount: Int = .init(try reader.readVarint())
        var authorizationTokens: [AuthorizationToken] = []
        var deliveryTimeout: UInt64?
        for _ in 0 ..< paramCount {
            switch try? ControlMessageParameter.decode(from: reader) {
            case .authorizationToken(let token):
                authorizationTokens.append(token)
            case .deliveryTimeout(let value):
                deliveryTimeout = value
            default:
                break
            }
        }
        let resource: TrackResource = .init(
            trackNamespace: trackNamespace,
            trackName: trackName,
            authorizationToken: authorizationTokens.first
        )
        return .init(
            requestID: requestID,
            resource: resource,
            subscriberPriority: subscriberPriority,
            groupOrder: groupOrder,
            forward: forwardValue == 1,
            filter: filter,
            deliveryTimeout: deliveryTimeout
        )
    }

    private var parameters: [ControlMessageParameter] {
        var parameters: [ControlMessageParameter] = []
        if let authorizationToken: AuthorizationToken = resource.authorizationToken {
            parameters.append(.authorizationToken(authorizationToken))
        }
        if let deliveryTimeout {
            parameters.append(.deliveryTimeout(deliveryTimeout))
        }
        return parameters
    }

    private var filterPayload: Data {
        var data: Data = .init()
        switch filter {
        case .nextGroupStart:
            data.writeVarint(0x01)
        case .largestObject:
            data.writeVarint(0x02)
        case .absoluteStart(let location):
            data.writeVarint(0x03)
            data.append(location.encode())
        case .absoluteRange(let start, let endGroup):
            data.writeVarint(0x04)
            data.append(start.encode())
            data.writeVarint(endGroup)
        }
        return data
    }

    private static func decodeFilter(from reader: ByteReader) throws -> SubscriptionFilter {
        let filterType: UInt64 = try reader.readVarint()
        switch filterType {
        case 0x01:
            return .nextGroupStart
        case 0x02:
            return .largestObject
        case 0x03:
            return .absoluteStart(try .decode(from: reader))
        case 0x04:
            let start: Location = try .decode(from: reader)
            let endGroup: UInt64 = try reader.readVarint()
            return .absoluteRange(start: start, endGroup: endGroup)
        default:
            throw SubscribeMessageError.invalidFilterType
        }
    }
}

enum SubscribeMessageError: Error {
    case invalidFilterType
    case invalidForward
    case invalidGroupOrder
}
