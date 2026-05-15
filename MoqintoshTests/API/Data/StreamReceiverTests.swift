//
//  StreamReceiverTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct StreamReceiverTests {

    @Test func inboundObjectYieldsObject() async throws {
        let header: SubgroupHeader = SubgroupHeader(trackAlias: 7, groupID: 4, subgroupID: .explicit(5), publisherPriority: 6)
        let object: SubgroupObject = header.makeObject(objectID: 0, content: .payload(ReadOnlyBytes(Data("abc".utf8))))
        let stream: MockTransportUniReceiveStream = MockTransportUniReceiveStream(
            receiveQueue: [TransportUniReceiveResult(bytes: object.encode(), isComplete: true)],
            receiveError: nil
        )
        let receiver: StreamReceiver = StreamReceiver(
            stream: stream,
            header: header,
            initialData: Data()
        )
        let receivedObject: SubgroupObject? = try await receiver.receive()

        #expect(receivedObject?.objectID == 0)
    }

    @Test func chunkedObjectYieldsObject() async throws {
        let header: SubgroupHeader = SubgroupHeader(trackAlias: 7, groupID: 4, subgroupID: .explicit(5), publisherPriority: 6)
        let object: SubgroupObject = header.makeObject(objectID: 0, content: .payload(ReadOnlyBytes(Data("abcdef".utf8))))
        let encoded: Data = object.encode()
        let stream: MockTransportUniReceiveStream = MockTransportUniReceiveStream(
            receiveQueue: [
                TransportUniReceiveResult(bytes: Data(encoded.prefix(2)), isComplete: false),
                TransportUniReceiveResult(bytes: Data(encoded.dropFirst(2)), isComplete: true)
            ],
            receiveError: nil
        )
        let receiver: StreamReceiver = StreamReceiver(
            stream: stream,
            header: header,
            initialData: Data()
        )
        let receivedObject: SubgroupObject? = try await receiver.receive()

        if case .payload(let payload) = receivedObject?.content {
            #expect(payload.equals(Data("abcdef".utf8)))
        } else {
            Issue.record("Expected payload content")
        }
    }
}
