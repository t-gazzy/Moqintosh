//
//  SubscribeNamespaceMessage.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// MOQT SUBSCRIBE_NAMESPACE message (Section 9.28, Type = 0x11)
///
/// Wire format:
/// ```
/// SUBSCRIBE_NAMESPACE {
///   Type (i) = 0x11,
///   Length (16),
///   Request ID (i),
///   Track Namespace Prefix (tuple),
///   Number of Parameters (i),
///   Parameters (..) ...,
/// }
/// ```
struct SubscribeNamespaceMessage {

    static let type: MessageType = .subscribeNamespace

    let requestID: UInt64
    let namespacePrefix: TrackNamespace
    let parameters: [SetupParameter]

    init(requestID: UInt64, namespacePrefix: TrackNamespace, parameters: [SetupParameter] = []) {
        self.requestID = requestID
        self.namespacePrefix = namespacePrefix
        self.parameters = parameters
    }

    // MARK: - Encode

    func encode() -> Data {
        var payload = Data()
        payload.writeVarint(requestID)
        payload.append(namespacePrefix.encode())
        payload.writeVarint(UInt64(parameters.count))
        for parameter in parameters {
            payload.append(parameter.encode())
        }

        var message = Data()
        message.writeVarint(SubscribeNamespaceMessage.type.rawValue)
        let length = UInt16(payload.count)
        message.append(UInt8(length >> 8))
        message.append(UInt8(length & 0xFF))
        message.append(payload)
        return message
    }

    // MARK: - Decode

    static func decode(from payload: Data) throws -> SubscribeNamespaceMessage {
        let reader = ByteReader(data: payload)
        let requestID = try reader.readVarint()
        let namespacePrefix = try TrackNamespace.decode(from: reader)
        let paramCount = Int(try reader.readVarint())
        var params: [SetupParameter] = []
        for _ in 0 ..< paramCount {
            if let param = try? SetupParameter.decode(from: reader) {
                params.append(param)
            }
        }
        return SubscribeNamespaceMessage(requestID: requestID, namespacePrefix: namespacePrefix, parameters: params)
    }
}
