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

    @Test func inboundObjectYieldsObjectAndCloses() async throws {
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
        receiver.start()

        let receivedObject: SubgroupObject? = try await receiver.receive()
        let closedObject: SubgroupObject? = try await receiver.receive()

        #expect(closedObject == nil)
        #expect(receivedObject?.groupID == 4)
        #expect(receivedObject?.objectID == 6)
        if case .payload(let payload) = receivedObject?.content {
            #expect(payload.equals(Data("abc".utf8)))
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
