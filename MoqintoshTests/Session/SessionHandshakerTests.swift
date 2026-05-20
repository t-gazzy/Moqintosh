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

        let clientSetup: ClientSetupMessage = try decodeClientSetup(from: stream.sentBytes[0])
        let maxRequestID: UInt64? = maxRequestID(from: clientSetup)

        #expect(result.selectedVersion == 0xff00000E)
        #expect(stream.sentBytes.count == 1)
        #expect(stream.sentBytes[0].first == UInt8(MessageType.clientSetup.rawValue))
        #expect(maxRequestID == 1000)
    }

    @Test func handshakeSendsConfiguredInitialMaxRequestID() async throws {
        let serverSetup: ServerSetupMessage = ServerSetupMessage(selectedVersion: 0xff00000E, parameters: [.maxRequestId(10)])
        let stream: MockTransportBiStream = MockTransportBiStream(receiveQueue: [serverSetup.encode()])
        let handshaker: SessionHandshaker = SessionHandshaker(stream: stream, initialMaxRequestID: 42)

        _ = try await handshaker.handshake()

        let clientSetup: ClientSetupMessage = try decodeClientSetup(from: stream.sentBytes[0])
        let maxRequestID: UInt64? = maxRequestID(from: clientSetup)
        #expect(maxRequestID == 42)
    }

    @Test func handshakeRejectsUnexpectedMessage() async {
        let publishError: PublishErrorMessage = PublishErrorMessage(requestID: 1, errorCode: 2, reasonPhrase: "bad")
        let stream: MockTransportBiStream = MockTransportBiStream(receiveQueue: [publishError.encode()])
        let handshaker: SessionHandshaker = SessionHandshaker(stream: stream)

        await #expect(throws: SessionHandshakerError.self) {
            try await handshaker.handshake()
        }
    }

    private func decodeClientSetup(from bytes: Data) throws -> ClientSetupMessage {
        try ClientSetupMessage.decode(from: Data(bytes.dropFirst(3)))
    }

    private func maxRequestID(from clientSetup: ClientSetupMessage) -> UInt64? {
        clientSetup.parameters.compactMap { parameter in
            if case .maxRequestId(let value) = parameter {
                return value
            }
            return nil
        }.first
    }
}
