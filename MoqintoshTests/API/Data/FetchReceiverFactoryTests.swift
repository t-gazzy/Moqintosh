//
//  FetchReceiverFactoryTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/12.
//

import Foundation
import Testing
@testable import Moqintosh

struct FetchReceiverFactoryTests {

    @Test func inboundUniStreamCreatesReceiver() async {
        let controlStream: MockTransportBiStream = MockTransportBiStream()
        let connection: MockTransportConnection = MockTransportConnection(biStream: controlStream)
        let context: SessionContext = SessionContext(connection: connection, controlStream: controlStream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: controlStream, dispatcher: ControlMessageDispatcher(sessionContext: context))
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)
        let subscriber: Subscriber = session.makeSubscriber()
        let fetchSubscription: FetchSubscription = FetchSubscription(
            requestID: 1,
            resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("video".utf8)),
            subscriberPriority: 0,
            groupOrder: .ascending,
            endOfTrack: true,
            endLocation: Location(group: 3, object: 4),
            maxCacheDuration: nil
        )
        let factory: FetchReceiverFactory = subscriber.makeFetchReceiverFactory(for: fetchSubscription)
        let delegate: TestFetchReceiverFactoryDelegate = TestFetchReceiverFactoryDelegate()
        factory.delegate = delegate
        let stream: MockTransportUniReceiveStream = MockTransportUniReceiveStream(
            receiveQueue: [TransportUniReceiveResult(bytes: FetchHeader(requestID: 1).encode(), isComplete: false)],
            receiveError: nil
        )

        connection.receiveUniStream(stream)

        while delegate.receivers.isEmpty {
            await Task.yield()
        }

        #expect(delegate.receivers.count == 1)
        #expect(delegate.receivers[0].fetchSubscription.requestID == 1)
    }
}
