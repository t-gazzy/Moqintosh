//
//  MoqintoshStreamMediaSender.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation
import Moqintosh

// Safe because the wrapped sender serializes stream object state internally.
public final class MoqintoshStreamMediaSender: @unchecked Sendable, RealtimeMediaPacketSender {
    private let sender: StreamSender
    private let endOfGroupProvider: @Sendable (TimedMediaPacket) -> Bool

    public init(
        sender: StreamSender,
        endOfGroupProvider: @escaping @Sendable (TimedMediaPacket) -> Bool = { _ in false }
    ) {
        self.sender = sender
        self.endOfGroupProvider = endOfGroupProvider
    }

    public func send(_ packet: TimedMediaPacket) async throws {
        let encodedPayload: Data = RealtimeMediaPacketPayloadCodec.encode(packet)
        try await sender.send(
            objectID: packet.sequenceNumber,
            endOfGroup: endOfGroupProvider(packet),
            content: StreamSender.Content.payload(ReadOnlyBytes(encodedPayload))
        )
    }
}
