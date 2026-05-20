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
        let controlStream: MockTransportBiStream = MockTransportBiStream(
            receiveQueue: [ServerSetupMessage(selectedVersion: 0xff00000E, parameters: [.maxRequestId(10)]).encode()]
        )
        let connection: MockTransportConnection = MockTransportConnection(biStream: controlStream)
        let endpoint: MockTransportEndpoint = MockTransportEndpoint(connection: connection)
        let factory: SessionFactory = SessionFactory()

        let session: Session = try await factory.connect(
            transportEndpoint: endpoint,
            initialIncomingRequestIDLimit: 42
        )
        let clientSetup: ClientSetupMessage = try ClientSetupMessage.decode(
            from: Data(connection.biStream.sentBytes[0].dropFirst(3))
        )
        let maxRequestID: UInt64? = clientSetup.parameters.compactMap { parameter in
            if case .maxRequestId(let value) = parameter {
                return value
            }
            return nil
        }.first

        #expect(endpoint.connectCallCount == 1)
        #expect(connection.biStream.sentBytes.count == 1)
        #expect(connection.biStream.sentBytes[0].first == UInt8(MessageType.clientSetup.rawValue))
        #expect(maxRequestID == 42)
        #expect(type(of: session.makePublisher()) == Publisher.self)
        #expect(type(of: session.makeSubscriber()) == Subscriber.self)
    }
}
