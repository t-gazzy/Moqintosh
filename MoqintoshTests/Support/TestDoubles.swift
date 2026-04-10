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
    private let lock: NSLock

    init(receiveQueue: [Data] = [], receiveError: (any Error)? = CancellationError()) {
        self.receiveQueue = receiveQueue
        self.sentBytes = []
        self.receiveError = receiveError
        self.lock = .init()
    }

    func receive() async throws -> Data {
        lock.lock()
        if let bytes: Data = receiveQueue.first {
            receiveQueue.removeFirst()
            lock.unlock()
            return bytes
        }
        let receiveError: (any Error)? = receiveError
        lock.unlock()
        if let receiveError {
            throw receiveError
        }
        return Data()
    }

    func send(bytes: Data) async throws {
        lock.lock()
        sentBytes.append(bytes)
        lock.unlock()
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

    init(
        biStream: MockTransportBiStream = .init(),
        uniStream: MockTransportUniStream = .init()
    ) {
        self.biStream = biStream
        self.uniStream = uniStream
    }

    func openBiStream() async throws -> TransportBiStream {
        biStream
    }

    func openUniStream() async throws -> TransportUniStream {
        uniStream
    }
}
