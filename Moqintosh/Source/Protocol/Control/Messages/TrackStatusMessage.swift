//
//  TrackStatusMessage.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

struct TrackStatusMessage {

    static let type: MessageType = .trackStatus

    let requestID: UInt64
    let resource: TrackResource
    let subscriberPriority: UInt8
    let groupOrder: GroupOrder
    let forward: Bool
    let filter: SubscriptionFilter

    func encode() -> Data {
        var payload: Data = Data()
        payload.writeVarint(requestID)
        payload.append(resource.trackNamespace.encode())
        payload.writeVarint(UInt64(resource.trackName.count))
        payload.append(resource.trackName)
        payload.append(subscriberPriority)
        payload.append(groupOrder.rawValue)
        payload.append(forward ? 1 : 0)
        payload.append(filter.encode())
        payload.writeVarint(UInt64(parameters.count))
        for parameter in parameters {
            payload.append(parameter.encode())
        }

        var message: Data = Data()
        message.writeVarint(Self.type.rawValue)
        let length: UInt16 = UInt16(payload.count)
        message.append(UInt8(length >> 8))
        message.append(UInt8(length & 0xFF))
        message.append(payload)
        return message
    }

    static func decode(from payload: Data) throws -> TrackStatusMessage {
        let reader: ByteReader = ByteReader(data: payload)
        let requestID: UInt64 = try reader.readVarint()
        let trackNamespace: TrackNamespace = try .decode(from: reader)
        let trackNameLength: Int = Int(try reader.readVarint())
        let trackName: Data = try reader.readBytes(length: trackNameLength)
        let subscriberPriority: UInt8 = try reader.readUInt8Value()
        let groupOrder: GroupOrder = try GroupOrder(rawValue: reader.readUInt8Value()) ?? {
            throw TrackStatusMessageError.invalidGroupOrder
        }()
        let forwardValue: UInt8 = try reader.readUInt8Value()
        guard forwardValue <= 1 else {
            throw TrackStatusMessageError.invalidForward
        }
        let filter: SubscriptionFilter = try .decode(from: reader)
        let parameterCount: Int = Int(try reader.readVarint())
        var authorizationToken: AuthorizationToken?
        for _ in 0 ..< parameterCount {
            if case .authorizationToken(let token) = try? ControlMessageParameter.decode(from: reader) {
                authorizationToken = token
            }
        }
        let resource: TrackResource = TrackResource(
            trackNamespace: trackNamespace,
            trackName: trackName,
            authorizationToken: authorizationToken
        )
        return TrackStatusMessage(
            requestID: requestID,
            resource: resource,
            subscriberPriority: subscriberPriority,
            groupOrder: groupOrder,
            forward: forwardValue == 1,
            filter: filter
        )
    }

    private var parameters: [ControlMessageParameter] {
        guard let authorizationToken: AuthorizationToken = resource.authorizationToken else {
            return []
        }
        return [.authorizationToken(authorizationToken)]
    }
}

enum TrackStatusMessageError: Error {
    case invalidForward
    case invalidGroupOrder
}
