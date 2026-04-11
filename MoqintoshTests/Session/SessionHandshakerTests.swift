//
//  SessionHandshakerTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct SessionHandshakerTests {

    @Test func handshakeSendsClientSetupAndReturnsServerSetup() async throws {
        let serverSetup: ServerSetupMessage = ServerSetupMessage(selectedVersion: 0xff00000E, parameters: [.maxRequestId(10)])
        let stream: MockTransportBiStream = MockTransportBiStream(receiveQueue: [serverSetup.encode()])
        let handshaker: SessionHandshaker = SessionHandshaker(stream: stream)

        let result: ServerSetupMessage = try await handshaker.handshake()

        #expect(result.selectedVersion == 0xff00000E)
        #expect(stream.sentBytes.count == 1)
        #expect(stream.sentBytes[0].first == UInt8(MessageType.clientSetup.rawValue))
    }

    @Test func handshakeRejectsUnexpectedMessage() async {
        let publishError: PublishErrorMessage = PublishErrorMessage(requestID: 1, errorCode: 2, reasonPhrase: "bad")
        let stream: MockTransportBiStream = MockTransportBiStream(receiveQueue: [publishError.encode()])
        let handshaker: SessionHandshaker = SessionHandshaker(stream: stream)

        await #expect(throws: SessionHandshakerError.self) {
            try await handshaker.handshake()
        }
    }
}
