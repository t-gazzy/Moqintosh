//
//  TestDoubles.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
@testable import Moqintosh

final class MockTransportBiStream: TransportBiStream {

    var receiveQueue: [Data]
    var sentBytes: [Data]
    var receiveError: (any Error)?
    private let stateQueue: DispatchQueue

    init(receiveQueue: [Data] = [], receiveError: (any Error)? = CancellationError()) {
        self.receiveQueue = receiveQueue
        self.sentBytes = []
        self.receiveError = receiveError
        self.stateQueue = .init(label: "MoqintoshTests.MockTransportBiStream")
    }

    func receive() async throws -> Data {
        let nextBytes: Data? = stateQueue.sync {
            guard !receiveQueue.isEmpty else { return nil }
            return receiveQueue.removeFirst()
        }
        if let nextBytes {
            return nextBytes
        }
        let receiveError: (any Error)? = stateQueue.sync {
            self.receiveError
        }
        if let receiveError {
            throw receiveError
        }
        return Data()
    }

    func send(bytes: Data) async throws {
        stateQueue.sync {
            sentBytes.append(bytes)
        }
    }
}

final class MockTransportUniStream: TransportUniStream {

    private(set) var sentBytes: [Data] = []

    func send(bytes: Data) async throws {
        sentBytes.append(bytes)
    }
}

final class MockTransportConnection: TransportConnection {

    weak var delegate: (any TransportConnectionDelegate)?
    var biStream: MockTransportBiStream
    var uniStream: MockTransportUniStream
    var additionalBiStreams: [MockTransportBiStream]
    var additionalUniStreams: [MockTransportUniStream]

    init(
        biStream: MockTransportBiStream = .init(),
        uniStream: MockTransportUniStream = .init(),
        additionalBiStreams: [MockTransportBiStream] = [],
        additionalUniStreams: [MockTransportUniStream] = []
    ) {
        self.biStream = biStream
        self.uniStream = uniStream
        self.additionalBiStreams = additionalBiStreams
        self.additionalUniStreams = additionalUniStreams
    }

    func openBiStream() async throws -> TransportBiStream {
        if !additionalBiStreams.isEmpty {
            return additionalBiStreams.removeFirst()
        }
        return biStream
    }

    func openUniStream() async throws -> TransportUniStream {
        if !additionalUniStreams.isEmpty {
            return additionalUniStreams.removeFirst()
        }
        return uniStream
    }
}
