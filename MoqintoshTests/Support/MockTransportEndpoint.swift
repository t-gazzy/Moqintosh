//
//  MockTransportEndpoint.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

@testable import Moqintosh

final class MockTransportEndpoint: TransportEndpoint {

    private let connection: TransportConnection
    private(set) var connectCallCount: Int

    init(connection: TransportConnection) {
        self.connection = connection
        self.connectCallCount = 0
    }

    func connect() async throws -> TransportConnection {
        connectCallCount += 1
        return connection
    }
}
