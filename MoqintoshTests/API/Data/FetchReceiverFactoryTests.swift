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
        let controlStream: MockTransportBiStream = .init()
        let connection: MockTransportConnection = .init(biStream: controlStream)
        let context: SessionContext = .init(connection: connection, controlStream: controlStream)
        let receiver: ControlMessageReceiver = .init(controlStream: controlStream, dispatcher: .init(sessionContext: context))
        let session: Session = .init(sessionContext: context, controlMessageReceiver: receiver)
        let subscriber: Subscriber = session.makeSubscriber()
        let fetchSubscription: FetchSubscription = .init(
            requestID: 1,
            resource: .init(trackNamespace: .init(strings: ["live"]), trackName: Data("video".utf8)),
            subscriberPriority: 0,
            groupOrder: .ascending,
            endOfTrack: true,
            endLocation: .init(group: 3, object: 4),
            maxCacheDuration: nil
        )
        let factory: FetchReceiverFactory = subscriber.makeFetchReceiverFactory(for: fetchSubscription)
        let delegate: TestFetchReceiverFactoryDelegate = .init()
        factory.delegate = delegate
        let stream: MockTransportUniReceiveStream = .init(
            receiveQueue: [.init(bytes: FetchHeader(requestID: 1).encode(), isComplete: false)],
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
