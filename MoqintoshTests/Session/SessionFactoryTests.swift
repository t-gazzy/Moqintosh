//
//  SessionFactoryTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct SessionFactoryTests {

    @Test func connectCreatesSessionAfterHandshake() async throws {
        let controlStream: MockTransportBiStream = .init(
            receiveQueue: [ServerSetupMessage(selectedVersion: 0xff00000E, parameters: [.maxRequestId(10)]).encode()]
        )
        let connection: MockTransportConnection = .init(biStream: controlStream)
        let endpoint: MockTransportEndpoint = .init(connection: connection)
        let factory: SessionFactory = .init()

        let session: Session = try await factory.connect(transportEndpoint: endpoint)

        #expect(endpoint.connectCallCount == 1)
        #expect(connection.biStream.sentBytes.count == 1)
        #expect(connection.biStream.sentBytes[0].first == UInt8(MessageType.clientSetup.rawValue))
        #expect(session.makePublisher().session === session)
        #expect(session.makeSubscriber().session === session)
    }
}
