//
//  MessageFrameReaderTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct MessageFrameReaderTests {

    @Test func readClientSetupAcrossChunks() async throws {
        let message: ClientSetupMessage = ClientSetupMessage(
            supportedVersions: [0xff00000E],
            parameters: [.maxRequestId(1)]
        )
        let encoded: Data = message.encode()
        let chunks: [Data] = [
            Data(encoded.prefix(2)),
            Data(encoded.dropFirst(2))
        ]
        let stream: MockTransportBiStream = MockTransportBiStream(receiveQueue: chunks)
        let reader: MessageFrameReader = MessageFrameReader()

        let decoded: MOQTMessage = try await reader.read(from: stream)

        guard case .clientSetup(let clientSetupMessage) = decoded else {
            Issue.record("Expected clientSetup")
            return
        }
        #expect(clientSetupMessage.supportedVersions == [0xff00000E])
    }

    @Test func readUnknownMessage() async throws {
        var frame: Data = Data()
        frame.writeVarint(0x99)
        frame.append(0x00)
        frame.append(0x02)
        frame.append(Data([0xAA, 0xBB]))
        let stream: MockTransportBiStream = MockTransportBiStream(receiveQueue: [frame])
        let reader: MessageFrameReader = MessageFrameReader()

        let decoded: MOQTMessage = try await reader.read(from: stream)

        guard case .unknown(let type, let payload) = decoded else {
            Issue.record("Expected unknown message")
            return
        }
        #expect(type == 0x99)
        #expect(payload == Data([0xAA, 0xBB]))
    }
}
