//
//  PublishMessage.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

struct PublishMessage {

    static let type: MessageType = .publish

    let requestID: UInt64
    let publishedTrack: PublishedTrack
    let deliveryTimeout: UInt64?
    let maxCacheDuration: UInt64?

    func encode() -> Data {
        var payload: Data = .init()
        payload.writeVarint(requestID)
        payload.append(publishedTrack.resource.trackNamespace.encode())
        payload.writeVarint(UInt64(publishedTrack.resource.trackName.count))
        payload.append(publishedTrack.resource.trackName)
        payload.writeVarint(publishedTrack.trackAlias)
        payload.append(publishedTrack.groupOrder.rawValue)
        payload.append(publishedTrack.contentExist.encode())
        payload.append(publishedTrack.forward ? 1 : 0)
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

    static func decode(from payload: Data) throws -> PublishMessage {
        let reader: ByteReader = .init(data: payload)
        let requestID: UInt64 = try reader.readVarint()
        let trackNamespace: TrackNamespace = try TrackNamespace.decode(from: reader)
        let trackNameLength: Int = .init(try reader.readVarint())
        let trackName: Data = try reader.readBytes(length: trackNameLength)
        let trackAlias: UInt64 = try reader.readVarint()
        let groupOrder: GroupOrder = try GroupOrder(rawValue: reader.readUInt8Value()) ?? {
            throw PublishMessageError.invalidGroupOrder
        }()
        let contentExist: ContentExist = try .decode(from: reader)
        let forwardValue: UInt8 = try reader.readUInt8Value()
        guard forwardValue <= 1 else {
            throw PublishMessageError.invalidForward
        }
        let paramCount: Int = .init(try reader.readVarint())
        var authorizationTokens: [AuthorizationToken] = []
        var deliveryTimeout: UInt64?
        var maxCacheDuration: UInt64?
        for _ in 0 ..< paramCount {
            switch try? ControlMessageParameter.decode(from: reader) {
            case .authorizationToken(let token):
                authorizationTokens.append(token)
            case .deliveryTimeout(let value):
                deliveryTimeout = value
            case .maxCacheDuration(let value):
                maxCacheDuration = value
            default:
                break
            }
        }
        let resource: TrackResource = .init(
            trackNamespace: trackNamespace,
            trackName: trackName,
            authorizationToken: authorizationTokens.first
        )
        let publishedTrack: PublishedTrack = .init(
            requestID: requestID,
            resource: resource,
            trackAlias: trackAlias,
            groupOrder: groupOrder,
            contentExist: contentExist,
            forward: forwardValue == 1
        )
        return .init(
            requestID: requestID,
            publishedTrack: publishedTrack,
            deliveryTimeout: deliveryTimeout,
            maxCacheDuration: maxCacheDuration
        )
    }

    private var parameters: [ControlMessageParameter] {
        var parameters: [ControlMessageParameter] = []
        if let authorizationToken: AuthorizationToken = publishedTrack.resource.authorizationToken {
            parameters.append(.authorizationToken(authorizationToken))
        }
        if let deliveryTimeout {
            parameters.append(.deliveryTimeout(deliveryTimeout))
        }
        if let maxCacheDuration {
            parameters.append(.maxCacheDuration(maxCacheDuration))
        }
        return parameters
    }
}

enum PublishMessageError: Error {
    case invalidForward
    case invalidGroupOrder
}
