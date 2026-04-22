//
//  MoqintoshDatagramMediaSender.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation
import Moqintosh

// Safe because the wrapped sender forwards each datagram without shared mutable state.
public final class MoqintoshDatagramMediaSender: @unchecked Sendable, RealtimeMediaPacketSender {
    private let sender: DatagramSender
    private let groupIDProvider: @Sendable (TimedMediaPacket) -> UInt64
    private let publisherPriorityProvider: @Sendable (TimedMediaPacket) -> UInt8
    private let endOfGroupProvider: @Sendable (TimedMediaPacket) -> Bool

    public init(
        sender: DatagramSender,
        groupIDProvider: @escaping @Sendable (TimedMediaPacket) -> UInt64,
        publisherPriorityProvider: @escaping @Sendable (TimedMediaPacket) -> UInt8 = { _ in 0 },
        endOfGroupProvider: @escaping @Sendable (TimedMediaPacket) -> Bool = { _ in false }
    ) {
        self.sender = sender
        self.groupIDProvider = groupIDProvider
        self.publisherPriorityProvider = publisherPriorityProvider
        self.endOfGroupProvider = endOfGroupProvider
    }

    public convenience init(
        sender: DatagramSender,
        groupID: UInt64,
        publisherPriority: UInt8 = 0,
        endOfGroup: Bool = false
    ) {
        self.init(
            sender: sender,
            groupIDProvider: { _ in groupID },
            publisherPriorityProvider: { _ in publisherPriority },
            endOfGroupProvider: { _ in endOfGroup }
        )
    }

    public func send(_ packet: TimedMediaPacket) async throws {
        let encodedPayload: Data = RealtimeMediaPacketPayloadCodec.encode(packet)
        try await sender.send(
            groupID: groupIDProvider(packet),
            objectID: ObjectDatagram.ObjectID.explicit(packet.sequenceNumber),
            publisherPriority: publisherPriorityProvider(packet),
            endOfGroup: endOfGroupProvider(packet),
            content: ObjectDatagram.Content.payload(ReadOnlyBytes(encodedPayload))
        )
    }
}
