//
//  TrackStatusOKMessage.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

struct TrackStatusOKMessage {

    static let type: MessageType = .trackStatusOK

    let requestID: UInt64
    let trackStatus: TrackStatus

    func encode() -> Data {
        var payload: Data = .init()
        payload.writeVarint(requestID)
        payload.writeVarint(trackStatus.expires)
        payload.append(trackStatus.groupOrder.rawValue)
        payload.append(trackStatus.contentExist.encode())
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

    static func decode(from payload: Data) throws -> TrackStatusOKMessage {
        let reader: ByteReader = .init(data: payload)
        let requestID: UInt64 = try reader.readVarint()
        let expires: UInt64 = try reader.readVarint()
        let groupOrder: GroupOrder = try GroupOrder(rawValue: reader.readUInt8Value()) ?? {
            throw TrackStatusOKMessageError.invalidGroupOrder
        }()
        let contentExist: ContentExist = try .decode(from: reader)
        let parameterCount: Int = .init(try reader.readVarint())
        var deliveryTimeout: UInt64?
        var maxCacheDuration: UInt64?
        for _ in 0 ..< parameterCount {
            switch try? ControlMessageParameter.decode(from: reader) {
            case .deliveryTimeout(let value):
                deliveryTimeout = value
            case .maxCacheDuration(let value):
                maxCacheDuration = value
            default:
                break
            }
        }
        let trackStatus: TrackStatus = .init(
            expires: expires,
            groupOrder: groupOrder,
            contentExist: contentExist,
            deliveryTimeout: deliveryTimeout,
            maxCacheDuration: maxCacheDuration
        )
        return .init(requestID: requestID, trackStatus: trackStatus)
    }

    private var parameters: [ControlMessageParameter] {
        var parameters: [ControlMessageParameter] = []
        if let deliveryTimeout: UInt64 = trackStatus.deliveryTimeout {
            parameters.append(.deliveryTimeout(deliveryTimeout))
        }
        if let maxCacheDuration: UInt64 = trackStatus.maxCacheDuration {
            parameters.append(.maxCacheDuration(maxCacheDuration))
        }
        return parameters
    }
}

enum TrackStatusOKMessageError: Error {
    case invalidGroupOrder
}
