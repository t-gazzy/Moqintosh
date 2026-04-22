//
//  RealtimeMediaPacketPayloadCodecTests.swift
//  RealtimeMediaKitTests
//
//  Created by Codex on 2026/04/22.
//

import Foundation
import Testing
@testable import RealtimeMediaKit

struct RealtimeMediaPacketPayloadCodecTests {

    @Test func encodeAndDecodePacketPayload() throws {
        let packet: TimedMediaPacket = TimedMediaPacket(
            sequenceNumber: 42,
            timestamp: 1_000,
            duration: 20,
            payload: Data([0x01, 0x02, 0x03])
        )

        let encodedPayload: Data = RealtimeMediaPacketPayloadCodec.encode(packet)
        let decodedPacket: TimedMediaPacket = try RealtimeMediaPacketPayloadCodec.decode(
            sequenceNumber: packet.sequenceNumber,
            payload: encodedPayload
        )

        #expect(decodedPacket == packet)
    }

    @Test func decodeRejectsShortPayload() throws {
        let payload: Data = Data(repeating: 0, count: RealtimeMediaPacketPayloadCodec.headerByteCount - 1)

        #expect(throws: RealtimeMediaPacketPayloadCodecError.insufficientData(
            requiredByteCount: RealtimeMediaPacketPayloadCodec.headerByteCount,
            actualByteCount: payload.count
        )) {
            try RealtimeMediaPacketPayloadCodec.decode(sequenceNumber: 1, payload: payload)
        }
    }
}
