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

    @Test func inboundUniStreamYieldsReceiver() async {
        let controlStream: MockTransportBiStream = MockTransportBiStream()
        let connection: MockTransportConnection = MockTransportConnection(biStream: controlStream)
        let context: SessionContext = SessionContext(connection: connection, controlStream: controlStream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: controlStream)
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
        let stream: MockTransportUniReceiveStream = MockTransportUniReceiveStream(
            receiveQueue: [TransportUniReceiveResult(bytes: FetchHeader(requestID: 1).encode(), isComplete: false)],
            receiveError: nil
        )

        connection.receiveUniStream(stream)

        let fetchReceiver: FetchReceiver? = await factory.accept()

        #expect(fetchReceiver?.fetchSubscription.requestID == 1)
    }
}
