//
//  MoqintoshDatagramMediaReceiver.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation
import Moqintosh

// Safe because the wrapped receiver owns the receive cursor.
public final class MoqintoshDatagramMediaReceiver: @unchecked Sendable, RealtimeMediaPacketReceiver {
    private let receiver: DatagramReceiver

    public init(receiver: DatagramReceiver) {
        self.receiver = receiver
    }

    public func receive() async throws -> TimedMediaPacket? {
        guard let datagram: ObjectDatagram = await receiver.receive() else {
            return nil
        }

        switch datagram.content {
        case .payload(let payload):
            let sequenceNumber: UInt64 = try explicitObjectID(from: datagram.objectID)
            return try RealtimeMediaPacketPayloadCodec.decode(
                sequenceNumber: sequenceNumber,
                payload: payload.materialize()
            )
        case .status(let status):
            OSLogger.debug("Finished datagram media receiver with status: \(status)")
            return nil
        }
    }

    private func explicitObjectID(from objectID: ObjectDatagram.ObjectID) throws -> UInt64 {
        switch objectID {
        case .explicit(let value):
            return value
        case .none:
            throw MoqintoshDatagramMediaReceiverError.missingObjectID
        }
    }
}
