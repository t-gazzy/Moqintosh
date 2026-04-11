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

    @Test func inboundObjectNotifiesDelegate() async {
        let header: SubgroupHeader = SubgroupHeader(trackAlias: 7, groupID: 4, subgroupID: .explicit(5), publisherPriority: 6)
        let object: SubgroupObject = header.makeObject(objectID: 0, content: .payload(Data("abc".utf8)))
        let stream: MockTransportUniReceiveStream = MockTransportUniReceiveStream(
            receiveQueue: [TransportUniReceiveResult(bytes: object.encode(), isComplete: true)],
            receiveError: nil
        )
        let receiver: StreamReceiver = StreamReceiver(
            stream: stream,
            subscription: Subscription(
                requestID: 1,
                publishedTrack: PublishedTrack(
                    requestID: 1,
                    resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("video".utf8)),
                    trackAlias: 7,
                    groupOrder: .ascending,
                    contentExist: .noContent,
                    forward: true
                ),
                expires: 2,
                subscriberPriority: 3,
                filter: .largestObject
            ),
            header: header,
            initialData: .init()
        )
        let delegate: TestStreamReceiverDelegate = TestStreamReceiverDelegate()
        receiver.delegate = delegate

        receiver.start()

        while delegate.receivedObjects.isEmpty {
            await Task.yield()
        }

        #expect(delegate.receivedObjects.count == 1)
        #expect(delegate.receivedObjects[0].objectID == 0)
    }

    @Test func chunkedObjectNotifiesDelegate() async {
        let header: SubgroupHeader = SubgroupHeader(trackAlias: 7, groupID: 4, subgroupID: .explicit(5), publisherPriority: 6)
        let object: SubgroupObject = header.makeObject(objectID: 0, content: .payload(Data("abcdef".utf8)))
        let encoded: Data = object.encode()
        let stream: MockTransportUniReceiveStream = MockTransportUniReceiveStream(
            receiveQueue: [
                .init(bytes: Data(encoded.prefix(2)), isComplete: false),
                .init(bytes: Data(encoded.dropFirst(2)), isComplete: true)
            ],
            receiveError: nil
        )
        let receiver: StreamReceiver = StreamReceiver(
            stream: stream,
            subscription: Subscription(
                requestID: 1,
                publishedTrack: PublishedTrack(
                    requestID: 1,
                    resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("video".utf8)),
                    trackAlias: 7,
                    groupOrder: .ascending,
                    contentExist: .noContent,
                    forward: true
                ),
                expires: 2,
                subscriberPriority: 3,
                filter: .largestObject
            ),
            header: header,
            initialData: .init()
        )
        let delegate: TestStreamReceiverDelegate = TestStreamReceiverDelegate()
        receiver.delegate = delegate

        receiver.start()

        while delegate.receivedObjects.isEmpty {
            await Task.yield()
        }

        #expect(delegate.receivedObjects.count == 1)
        if case .payload(let payload) = delegate.receivedObjects[0].content {
            #expect(payload == Data("abcdef".utf8))
        } else {
            Issue.record("Expected payload content")
        }
    }
}
