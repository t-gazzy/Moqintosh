//
//  PublishNamespaceMessage.swift
//  Moqintosh
//
//  Created by Takemasa Kaji on 2026/04/10.
//

import Foundation

/// MOQT PUBLISH_NAMESPACE message (Section 9.23, Type = 0x06)
///
/// Wire format:
/// ```
/// PUBLISH_NAMESPACE {
///   Type (i) = 0x06,
///   Length (16),
///   Request ID (i),
///   Track Namespace (tuple),
///   Number of Parameters (i),
///   Parameters (..) ...,
/// }
/// ```
struct PublishNamespaceMessage {

    static let type: MessageType = .publishNamespace

    let requestID: UInt64
    let trackNamespace: TrackNamespace
    let authorizationTokens: [AuthorizationToken]

    init(
        requestID: UInt64,
        trackNamespace: TrackNamespace,
        authorizationTokens: [AuthorizationToken] = []
    ) {
        self.requestID = requestID
        self.trackNamespace = trackNamespace
        self.authorizationTokens = authorizationTokens
    }

    func encode() -> Data {
        var payload: Data = Data()
        payload.writeVarint(requestID)
        payload.append(trackNamespace.encode())
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

    static func decode(from payload: Data) throws -> PublishNamespaceMessage {
        let reader: ByteReader = ByteReader(data: payload)
        let requestID: UInt64 = try reader.readVarint()
        let trackNamespace: TrackNamespace = try TrackNamespace.decode(from: reader)
        let paramCount: Int = Int(try reader.readVarint())
        var authorizationTokens: [AuthorizationToken] = []
        for _ in 0 ..< paramCount {
            if case .authorizationToken(let token) = try? ControlMessageParameter.decode(from: reader) {
                authorizationTokens.append(token)
            }
        }
        return PublishNamespaceMessage(
            requestID: requestID,
            trackNamespace: trackNamespace,
            authorizationTokens: authorizationTokens
        )
    }

    private var parameters: [ControlMessageParameter] {
        authorizationTokens.map { .authorizationToken($0) }
    }
}
