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
    private var receiveContinuations: [CheckedContinuation<Data, Error>]

    init(receiveQueue: [Data] = [], receiveError: (any Error)? = CancellationError()) {
        self.receiveQueue = receiveQueue
        self.sentBytes = []
        self.receiveError = receiveError
        self.stateQueue = .init(label: "MoqintoshTests.MockTransportBiStream")
        self.receiveContinuations = []
    }

    func receive() async throws -> Data {
        enum ReceiveResult {
            case bytes(Data)
            case error(any Error)
            case wait
        }

        let result: ReceiveResult = stateQueue.sync {
            if !receiveQueue.isEmpty {
                return .bytes(receiveQueue.removeFirst())
            }
            if let receiveError {
                return .error(receiveError)
            }
            return .wait
        }

        switch result {
        case .bytes(let bytes):
            return bytes
        case .error(let error):
            throw error
        case .wait:
            return try await withCheckedThrowingContinuation { continuation in
                stateQueue.sync {
                    receiveContinuations.append(continuation)
                }
            }
        }
    }

    func send(bytes: Data) async throws {
        stateQueue.sync {
            sentBytes.append(bytes)
        }
    }

    func enqueueReceive(_ bytes: Data) {
        let continuation: CheckedContinuation<Data, Error>? = stateQueue.sync {
            if !receiveContinuations.isEmpty {
                return receiveContinuations.removeFirst()
            }
            receiveQueue.append(bytes)
            return nil
        }
        continuation?.resume(returning: bytes)
    }

    func finishReceiving(with error: any Error) {
        let continuations: [CheckedContinuation<Data, Error>] = stateQueue.sync {
            receiveError = error
            let continuations: [CheckedContinuation<Data, Error>] = receiveContinuations
            receiveContinuations.removeAll()
            return continuations
        }
        for continuation in continuations {
            continuation.resume(throwing: error)
        }
    }
}

final class MockTransportUniSendStream: TransportUniSendStream {

    private(set) var sentBytes: [Data]
    private(set) var endOfStreamFlags: [Bool]

    init() {
        self.sentBytes = []
        self.endOfStreamFlags = []
    }

    func send(bytes: Data, endOfStream: Bool) async throws {
        sentBytes.append(bytes)
        endOfStreamFlags.append(endOfStream)
    }
}

final class MockTransportUniReceiveStream: TransportUniReceiveStream {

    var receiveQueue: [TransportUniReceiveResult]
    var receiveError: (any Error)?

    init(receiveQueue: [TransportUniReceiveResult] = [], receiveError: (any Error)? = CancellationError()) {
        self.receiveQueue = receiveQueue
        self.receiveError = receiveError
    }

    func receive() async throws -> TransportUniReceiveResult {
        if !receiveQueue.isEmpty {
            return receiveQueue.removeFirst()
        }
        if let receiveError {
            throw receiveError
        }
        return .init(bytes: .init(), isComplete: false)
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
