//
//  StreamReceiverCoordinatorTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/12.
//

import Foundation
import Synchronization
import Testing
@testable import Moqintosh

struct StreamReceiverCoordinatorTests {

    @Test func inboundSubgroupStreamParsesHeaderAcrossChunksAndPassesTrailingBytes() async {
        let controlStream: MockTransportBiStream = MockTransportBiStream()
        let connection: MockTransportConnection = MockTransportConnection(biStream: controlStream)
        let context: SessionContext = SessionContext(connection: connection, controlStream: controlStream)
        let coordinator: StreamReceiverCoordinator = StreamReceiverCoordinator(sessionContext: context)
        let recorder: StreamReceiverInvocationRecorder = StreamReceiverInvocationRecorder()
        let header: SubgroupHeader = SubgroupHeader(
            trackAlias: 7,
            groupID: 4,
            subgroupID: .explicit(5),
            publisherPriority: 6
        )
        let initialData: Data = Data("tail".utf8)
        let encodedHeader: Data = header.encode()
        let stream: MockTransportUniReceiveStream = MockTransportUniReceiveStream(
            receiveQueue: [
                TransportUniReceiveResult(bytes: Data(encodedHeader.prefix(2)), isComplete: false),
                TransportUniReceiveResult(bytes: Data(encodedHeader.dropFirst(2)) + initialData, isComplete: false)
            ],
            receiveError: nil
        )
        connection.delegate = coordinator
        context.streamReceiverStore.register(trackAlias: 7) { receivedStream, receivedHeader, receivedInitialData in
            recorder.record(stream: receivedStream, header: receivedHeader, initialData: receivedInitialData)
        }

        connection.receiveUniStream(stream)

        while recorder.invocation == nil {
            await Task.yield()
        }

        guard let invocation: StreamReceiverInvocationRecorder.Invocation = recorder.invocation else {
            Issue.record("Expected stream handler invocation")
            return
        }
        #expect(invocation.stream as AnyObject === stream)
        #expect(invocation.header.trackAlias == 7)
        #expect(invocation.header.groupID == 4)
        if case .explicit(let subgroupID) = invocation.header.subgroupID {
            #expect(subgroupID == 5)
        } else {
            Issue.record("Expected an explicit subgroup ID")
        }
        #expect(invocation.initialData == initialData)
    }

    @Test func inboundFetchStreamParsesHeaderAcrossChunksAndPassesTrailingBytes() async {
        let controlStream: MockTransportBiStream = MockTransportBiStream()
        let connection: MockTransportConnection = MockTransportConnection(biStream: controlStream)
        let context: SessionContext = SessionContext(connection: connection, controlStream: controlStream)
        let coordinator: StreamReceiverCoordinator = StreamReceiverCoordinator(sessionContext: context)
        let recorder: FetchReceiverInvocationRecorder = FetchReceiverInvocationRecorder()
        let header: FetchHeader = FetchHeader(requestID: 11)
        let initialData: Data = Data("tail".utf8)
        let encodedHeader: Data = header.encode()
        let stream: MockTransportUniReceiveStream = MockTransportUniReceiveStream(
            receiveQueue: [
                TransportUniReceiveResult(bytes: Data(encodedHeader.prefix(1)), isComplete: false),
                TransportUniReceiveResult(bytes: Data(encodedHeader.dropFirst(1)) + initialData, isComplete: false)
            ],
            receiveError: nil
        )
        connection.delegate = coordinator
        context.fetchReceiverStore.register(requestID: 11) { receivedStream, receivedHeader, receivedInitialData in
            recorder.record(stream: receivedStream, header: receivedHeader, initialData: receivedInitialData)
        }

        connection.receiveUniStream(stream)

        while recorder.invocation == nil {
            await Task.yield()
        }

        guard let invocation: FetchReceiverInvocationRecorder.Invocation = recorder.invocation else {
            Issue.record("Expected fetch handler invocation")
            return
        }
        #expect(invocation.stream as AnyObject === stream)
        #expect(invocation.header.requestID == 11)
        #expect(invocation.initialData == initialData)
    }
}

private final class StreamReceiverInvocationRecorder: Sendable {

    struct Invocation: Sendable {

        let stream: any TransportUniReceiveStream
        let header: SubgroupHeader
        let initialData: Data
    }

    private let state: Mutex<Invocation?>

    init() {
        self.state = Mutex<Invocation?>(nil)
    }

    var invocation: Invocation? {
        state.withLock { state in
            state
        }
    }

    func record(stream: any TransportUniReceiveStream, header: SubgroupHeader, initialData: Data) {
        state.withLock { state in
            state = Invocation(stream: stream, header: header, initialData: initialData)
        }
    }
}

private final class FetchReceiverInvocationRecorder: Sendable {

    struct Invocation: Sendable {

        let stream: any TransportUniReceiveStream
        let header: FetchHeader
        let initialData: Data
    }

    private let state: Mutex<Invocation?>

    init() {
        self.state = Mutex<Invocation?>(nil)
    }

    var invocation: Invocation? {
        state.withLock { state in
            state
        }
    }

    func record(stream: any TransportUniReceiveStream, header: FetchHeader, initialData: Data) {
        state.withLock { state in
            state = Invocation(stream: stream, header: header, initialData: initialData)
        }
    }
}
