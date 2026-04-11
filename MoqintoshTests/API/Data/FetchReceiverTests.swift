//
//  FetchReceiverTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/12.
//

import Foundation
import Testing
@testable import Moqintosh

struct FetchReceiverTests {

    @Test func inboundObjectNotifiesDelegateAndCloses() async {
        let stream: MockTransportUniReceiveStream = MockTransportUniReceiveStream(
            receiveQueue: [TransportUniReceiveResult(bytes: makeFetchObjectPayload(payload: Data("abc".utf8)), isComplete: true)],
            receiveError: nil
        )
        let receiver: FetchReceiver = FetchReceiver(
            stream: stream,
            fetchSubscription: FetchSubscription(
                requestID: 1,
                resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("video".utf8)),
                subscriberPriority: 0,
                groupOrder: .ascending,
                endOfTrack: true,
                endLocation: Location(group: 3, object: 4),
                maxCacheDuration: nil
            ),
            initialData: Data()
        )
        let delegate: TestFetchReceiverDelegate = TestFetchReceiverDelegate()
        receiver.delegate = delegate

        receiver.start()

        while delegate.receivedObjects.isEmpty {
            await Task.yield()
        }
        while delegate.closedReceiverCount < 1 {
            await Task.yield()
        }

        #expect(delegate.receivedObjects.count == 1)
        #expect(delegate.closedReceiverCount == 1)
        #expect(delegate.receivedObjects[0].groupID == 4)
        #expect(delegate.receivedObjects[0].objectID == 6)
        if case .payload(let payload) = delegate.receivedObjects[0].content {
            #expect(payload == Data("abc".utf8))
        } else {
            Issue.record("Expected payload content")
        }
    }
}

private func makeFetchObjectPayload(payload: Data) -> Data {
    var data: Data = Data()
    data.writeVarint(4)
    data.writeVarint(5)
    data.writeVarint(6)
    data.append(7)
    data.writeVarint(0)
    data.writeVarint(UInt64(payload.count))
    data.append(payload)
    return data
}
