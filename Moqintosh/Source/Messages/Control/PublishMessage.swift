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

    func encode() -> Data {
        var payload: Data = .init()
        payload.writeVarint(requestID)
        payload.append(publishedTrack.resource.trackNamespace.encode())
        payload.writeVarint(UInt64(publishedTrack.resource.trackName.count))
        payload.append(publishedTrack.resource.trackName)
        payload.writeVarint(publishedTrack.trackAlias)
        payload.append(publishedTrack.groupOrder.rawValue)
        payload.append(publishedTrack.contentExists ? 1 : 0)
        if let largestLocation: Location = publishedTrack.largestLocation {
            payload.append(largestLocation.encode())
        }
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
        let contentExistsValue: UInt8 = try reader.readUInt8Value()
        guard contentExistsValue <= 1 else {
            throw PublishMessageError.invalidContentExists
        }
        let largestLocation: Location? = contentExistsValue == 1 ? try .decode(from: reader) : nil
        let forwardValue: UInt8 = try reader.readUInt8Value()
        guard forwardValue <= 1 else {
            throw PublishMessageError.invalidForward
        }
        let paramCount: Int = .init(try reader.readVarint())
        var parameters: [SetupParameter] = []
        for _ in 0 ..< paramCount {
            if let parameter: SetupParameter = try? SetupParameter.decode(from: reader) {
                parameters.append(parameter)
            }
        }
        let resource: TrackResource = .init(
            trackNamespace: trackNamespace,
            trackName: trackName,
            authorizationToken: firstAuthorizationToken(in: parameters)
        )
        let publishedTrack: PublishedTrack = .init(
            requestID: requestID,
            resource: resource,
            trackAlias: trackAlias,
            groupOrder: groupOrder,
            contentExists: contentExistsValue == 1,
            largestLocation: largestLocation,
            forward: forwardValue == 1
        )
        return .init(requestID: requestID, publishedTrack: publishedTrack)
    }

    private var parameters: [SetupParameter] {
        guard let authorizationToken: AuthorizationToken = publishedTrack.resource.authorizationToken else {
            return []
        }
        return [.authorizationToken(authorizationToken)]
    }

    private static func firstAuthorizationToken(in parameters: [SetupParameter]) -> AuthorizationToken? {
        for parameter in parameters {
            if case .authorizationToken(let token) = parameter {
                return token
            }
        }
        return nil
    }
}

enum PublishMessageError: Error {
    case invalidContentExists
    case invalidForward
    case invalidGroupOrder
}
