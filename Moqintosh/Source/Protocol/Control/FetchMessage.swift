//
//  FetchMessage.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

struct FetchMessage {

    enum FetchType: UInt64 {
        case standalone = 0x1
        case joiningRelative = 0x2
        case joiningAbsolute = 0x3
    }

    enum Mode {
        case standalone(resource: TrackResource, start: Location, end: Location)
        case joiningRelative(joiningRequestID: UInt64, startGroupOffset: UInt64)
        case joiningAbsolute(joiningRequestID: UInt64, startGroup: UInt64)
    }

    static let type: MessageType = .fetch

    let requestID: UInt64
    let subscriberPriority: UInt8
    let groupOrder: GroupOrder
    let mode: Mode

    func encode() -> Data {
        var payload: Data = Data()
        payload.writeVarint(requestID)
        payload.append(subscriberPriority)
        payload.append(groupOrder.rawValue)
        payload.writeVarint(fetchType.rawValue)
        switch mode {
        case .standalone(let resource, let start, let end):
            payload.append(resource.trackNamespace.encode())
            payload.writeVarint(UInt64(resource.trackName.count))
            payload.append(resource.trackName)
            payload.append(start.encode())
            payload.append(end.encode())
        case .joiningRelative(let joiningRequestID, let startGroupOffset):
            payload.writeVarint(joiningRequestID)
            payload.writeVarint(startGroupOffset)
        case .joiningAbsolute(let joiningRequestID, let startGroup):
            payload.writeVarint(joiningRequestID)
            payload.writeVarint(startGroup)
        }
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

    static func decode(from payload: Data) throws -> FetchMessage {
        let reader: ByteReader = ByteReader(data: payload)
        let requestID: UInt64 = try reader.readVarint()
        let subscriberPriority: UInt8 = try reader.readUInt8Value()
        let groupOrder: GroupOrder = try GroupOrder(rawValue: reader.readUInt8Value()) ?? {
            throw FetchMessageError.invalidGroupOrder
        }()
        let fetchTypeRawValue: UInt64 = try reader.readVarint()
        guard let fetchType: FetchType = FetchType(rawValue: fetchTypeRawValue) else {
            throw FetchMessageError.invalidFetchType(fetchTypeRawValue)
        }
        let mode: Mode
        switch fetchType {
        case .standalone:
            let trackNamespace: TrackNamespace = try .decode(from: reader)
            let trackNameLength: Int = Int(try reader.readVarint())
            let trackName: Data = try reader.readBytes(length: trackNameLength)
            let start: Location = try .decode(from: reader)
            let end: Location = try .decode(from: reader)
            mode = .standalone(
                resource: TrackResource(trackNamespace: trackNamespace, trackName: trackName),
                start: start,
                end: end
            )
        case .joiningRelative:
            mode = .joiningRelative(
                joiningRequestID: try reader.readVarint(),
                startGroupOffset: try reader.readVarint()
            )
        case .joiningAbsolute:
            mode = .joiningAbsolute(
                joiningRequestID: try reader.readVarint(),
                startGroup: try reader.readVarint()
            )
        }
        let parameterCount: Int = Int(try reader.readVarint())
        var authorizationToken: AuthorizationToken?
        for _ in 0 ..< parameterCount {
            if case .authorizationToken(let token) = try? ControlMessageParameter.decode(from: reader) {
                authorizationToken = token
            }
        }
        let adjustedMode: Mode
        switch mode {
        case .standalone(let resource, let start, let end):
            adjustedMode = .standalone(
                resource: TrackResource(
                    trackNamespace: resource.trackNamespace,
                    trackName: resource.trackName,
                    authorizationToken: authorizationToken
                ),
                start: start,
                end: end
            )
        case .joiningRelative, .joiningAbsolute:
            adjustedMode = mode
        }
        return FetchMessage(
            requestID: requestID,
            subscriberPriority: subscriberPriority,
            groupOrder: groupOrder,
            mode: adjustedMode
        )
    }

    private var fetchType: FetchType {
        switch mode {
        case .standalone:
            return .standalone
        case .joiningRelative:
            return .joiningRelative
        case .joiningAbsolute:
            return .joiningAbsolute
        }
    }

    private var parameters: [ControlMessageParameter] {
        switch mode {
        case .standalone(let resource, _, _):
            guard let authorizationToken: AuthorizationToken = resource.authorizationToken else {
                return []
            }
            return [.authorizationToken(authorizationToken)]
        case .joiningRelative, .joiningAbsolute:
            return []
        }
    }
}

enum FetchMessageError: Error {
    case invalidFetchType(UInt64)
    case invalidGroupOrder
}
