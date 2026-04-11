//
//  FetchOKMessage.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

struct FetchOKMessage {

    static let type: MessageType = .fetchOK

    let requestID: UInt64
    let groupOrder: GroupOrder
    let endOfTrack: Bool
    let endLocation: Location
    let maxCacheDuration: UInt64?

    func encode() -> Data {
        var payload: Data = .init()
        payload.writeVarint(requestID)
        payload.append(groupOrder.rawValue)
        payload.append(endOfTrack ? 1 : 0)
        payload.append(endLocation.encode())
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

    static func decode(from payload: Data) throws -> FetchOKMessage {
        let reader: ByteReader = .init(data: payload)
        let requestID: UInt64 = try reader.readVarint()
        let groupOrder: GroupOrder = try GroupOrder(rawValue: reader.readUInt8Value()) ?? {
            throw FetchOKMessageError.invalidGroupOrder
        }()
        let endOfTrackValue: UInt8 = try reader.readUInt8Value()
        guard endOfTrackValue <= 1 else {
            throw FetchOKMessageError.invalidEndOfTrack
        }
        let endLocation: Location = try .decode(from: reader)
        let parameterCount: Int = .init(try reader.readVarint())
        var maxCacheDuration: UInt64?
        for _ in 0 ..< parameterCount {
            if case .maxCacheDuration(let value) = try? ControlMessageParameter.decode(from: reader) {
                maxCacheDuration = value
            }
        }
        return .init(
            requestID: requestID,
            groupOrder: groupOrder,
            endOfTrack: endOfTrackValue == 1,
            endLocation: endLocation,
            maxCacheDuration: maxCacheDuration
        )
    }

    private var parameters: [ControlMessageParameter] {
        guard let maxCacheDuration: UInt64 else {
            return []
        }
        return [.maxCacheDuration(maxCacheDuration)]
    }
}

enum FetchOKMessageError: Error {
    case invalidEndOfTrack
    case invalidGroupOrder
}
