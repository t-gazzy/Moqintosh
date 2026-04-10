//
//  SubscribeNamespaceOKMessage.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// MOQT SUBSCRIBE_NAMESPACE_OK message (Section 9.29, Type = 0x12)
///
/// Wire format:
/// ```
/// SUBSCRIBE_NAMESPACE_OK {
///   Type (i) = 0x12,
///   Length (16),
///   Request ID (i),
/// }
/// ```
struct SubscribeNamespaceOKMessage {

    static let type: MessageType = .subscribeNamespaceOK

    let requestID: UInt64

    // MARK: - Decode

    static func decode(from payload: Data) throws -> SubscribeNamespaceOKMessage {
        let reader = ByteReader(data: payload)
        let requestID = try reader.readVarint()
        return SubscribeNamespaceOKMessage(requestID: requestID)
    }
}
