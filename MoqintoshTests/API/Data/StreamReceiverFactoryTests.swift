//
//  StreamReceiverFactoryTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct StreamReceiverFactoryTests {

    @Test func inboundUniStreamCreatesReceiver() async {
        let controlStream: MockTransportBiStream = MockTransportBiStream()
        let connection: MockTransportConnection = MockTransportConnection(biStream: controlStream)
        let context: SessionContext = SessionContext(connection: connection, controlStream: controlStream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: controlStream)
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)
        let subscriber: Subscriber = session.makeSubscriber()
        let subscription: Subscription = Subscription(
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
        )
        let factory: StreamReceiverFactory = subscriber.makeStreamReceiverFactory(for: subscription)
        let delegate: TestStreamReceiverFactoryDelegate = TestStreamReceiverFactoryDelegate()
        factory.delegate = delegate
        let header: SubgroupHeader = SubgroupHeader(trackAlias: 7, groupID: 4, subgroupID: .explicit(5), publisherPriority: 6)
        let stream: MockTransportUniReceiveStream = MockTransportUniReceiveStream(
            receiveQueue: [TransportUniReceiveResult(bytes: header.encode(), isComplete: false)],
            receiveError: nil
        )

        connection.receiveUniStream(stream)

        while delegate.receivers.isEmpty {
            await Task.yield()
        }

        #expect(delegate.receivers.count == 1)
        #expect(delegate.receivers[0].header.subgroupID == .explicit(5))
    }
}
