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

final class MockTransportUniSendStream: TransportUniSendStream {

    private(set) var sentBytes: [Data]

    init() {
        self.sentBytes = []
    }

    func send(bytes: Data) async throws {
        sentBytes.append(bytes)
    }
}

final class MockTransportUniReceiveStream: TransportUniReceiveStream {

    var receiveQueue: [Data]
    var receiveError: (any Error)?

    init(receiveQueue: [Data] = [], receiveError: (any Error)? = CancellationError()) {
        self.receiveQueue = receiveQueue
        self.receiveError = receiveError
    }

    func receive() async throws -> Data {
        if !receiveQueue.isEmpty {
            return receiveQueue.removeFirst()
        }
        if let receiveError {
            throw receiveError
        }
        return Data()
    }
}

final class MockTransportConnection: TransportConnection {

    weak var delegate: (any TransportConnectionDelegate)?
    var biStream: MockTransportBiStream
    var uniSendStream: MockTransportUniSendStream
    var uniReceiveStream: MockTransportUniReceiveStream
    var additionalBiStreams: [MockTransportBiStream]
    var additionalUniSendStreams: [MockTransportUniSendStream]
    private(set) var sentDatagrams: [Data]

    init(
        biStream: MockTransportBiStream = .init(),
        uniSendStream: MockTransportUniSendStream = .init(),
        uniReceiveStream: MockTransportUniReceiveStream = .init(),
        additionalBiStreams: [MockTransportBiStream] = [],
        additionalUniSendStreams: [MockTransportUniSendStream] = []
    ) {
        self.biStream = biStream
        self.uniSendStream = uniSendStream
        self.uniReceiveStream = uniReceiveStream
        self.additionalBiStreams = additionalBiStreams
        self.additionalUniSendStreams = additionalUniSendStreams
        self.sentDatagrams = []
    }

    func openBiStream() async throws -> TransportBiStream {
        if !additionalBiStreams.isEmpty {
            return additionalBiStreams.removeFirst()
        }
        return biStream
    }

    func openUniStream() async throws -> TransportUniSendStream {
        if !additionalUniSendStreams.isEmpty {
            return additionalUniSendStreams.removeFirst()
        }
        return uniSendStream
    }

    func sendDatagram(bytes: Data) async throws {
        sentDatagrams.append(bytes)
    }

    func receiveDatagram(bytes: Data) {
        delegate?.connection(self, didReceiveDatagram: bytes)
    }

    func receiveUniStream(_ stream: MockTransportUniReceiveStream? = nil) {
        delegate?.connection(self, didReceiveUniStream: stream ?? uniReceiveStream)
    }
}
