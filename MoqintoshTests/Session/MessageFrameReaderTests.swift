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

    @Test func readMessageWhenHeaderAndPayloadAreFragmentedAcrossMultipleChunks() async throws {
        let message: SubscribeNamespaceMessage = SubscribeNamespaceMessage(
            requestID: 8,
            namespacePrefix: TrackNamespace(strings: ["live", "video"]),
            authorizationTokens: [AuthorizationToken(value: Data([0xAA, 0xBB]))]
        )
        let encoded: Data = message.encode()
        let chunks: [Data] = encoded.map { Data([$0]) }
        let stream: MockTransportBiStream = MockTransportBiStream(receiveQueue: chunks)
        let reader: MessageFrameReader = MessageFrameReader()

        let decoded: MOQTMessage = try await reader.read(from: stream)

        guard case .subscribeNamespace(let subscribeNamespaceMessage) = decoded else {
            Issue.record("Expected subscribeNamespace")
            return
        }
        #expect(subscribeNamespaceMessage.requestID == 8)
        #expect(subscribeNamespaceMessage.namespacePrefix.elements == [Data("live".utf8), Data("video".utf8)])
        #expect(subscribeNamespaceMessage.authorizationTokens.count == 1)
        #expect(subscribeNamespaceMessage.authorizationTokens[0].value == Data([0xAA, 0xBB]))
    }

    @Test func readSequentialMessagesPreservesTrailingBytesInBuffer() async throws {
        let firstMessage: GoAwayMessage = GoAwayMessage(newSessionURI: "https://example.com/next")
        let secondMessage: MaxRequestIDMessage = MaxRequestIDMessage(requestID: 12)
        let firstEncoded: Data = firstMessage.encode()
        let secondEncoded: Data = secondMessage.encode()
        let firstChunk: Data = firstEncoded + secondEncoded.prefix(2)
        let secondChunk: Data = Data(secondEncoded.dropFirst(2))
        let stream: MockTransportBiStream = MockTransportBiStream(receiveQueue: [firstChunk, secondChunk])
        let reader: MessageFrameReader = MessageFrameReader()

        let firstDecoded: MOQTMessage = try await reader.read(from: stream)
        let secondDecoded: MOQTMessage = try await reader.read(from: stream)

        guard case .goaway(let goAwayMessage) = firstDecoded else {
            Issue.record("Expected goaway")
            return
        }
        #expect(goAwayMessage.newSessionURI == "https://example.com/next")

        guard case .maxRequestID(let maxRequestIDMessage) = secondDecoded else {
            Issue.record("Expected maxRequestID")
            return
        }
        #expect(maxRequestIDMessage.requestID == 12)
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
