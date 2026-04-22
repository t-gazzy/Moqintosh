//
//  MoqintoshStreamMediaReceiver.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation
import Moqintosh

// Safe because the wrapped receiver owns the receive cursor.
public final class MoqintoshStreamMediaReceiver: @unchecked Sendable, RealtimeMediaPacketReceiver {
    private let receiver: StreamReceiver

    public init(receiver: StreamReceiver) {
        self.receiver = receiver
    }

    public func receive() async throws -> TimedMediaPacket? {
        guard let object: SubgroupObject = try await receiver.receive() else {
            return nil
        }

        switch object.content {
        case .payload(let payload):
            return try RealtimeMediaPacketPayloadCodec.decode(
                sequenceNumber: object.objectID,
                payload: payload.materialize()
            )
        case .status(let status):
            OSLogger.debug("Finished stream media receiver with status: \(status)")
            return nil
        }
    }
}
