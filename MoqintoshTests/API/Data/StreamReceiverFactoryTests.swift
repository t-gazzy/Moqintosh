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
        let controlStream: MockTransportBiStream = .init()
        let connection: MockTransportConnection = .init(biStream: controlStream)
        let context: SessionContext = .init(connection: connection, controlStream: controlStream)
        let receiver: ControlMessageReceiver = .init(controlStream: controlStream, dispatcher: .init(sessionContext: context))
        let session: Session = .init(sessionContext: context, controlMessageReceiver: receiver)
        let subscriber: Subscriber = session.makeSubscriber()
        let subscription: Subscription = .init(
            requestID: 1,
            publishedTrack: .init(
                requestID: 1,
                resource: .init(trackNamespace: .init(strings: ["live"]), trackName: Data("video".utf8)),
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
        let delegate: TestStreamReceiverFactoryDelegate = .init()
        factory.delegate = delegate
        let header: SubgroupHeader = .init(trackAlias: 7, groupID: 4, subgroupID: .explicit(5), publisherPriority: 6)
        let stream: MockTransportUniReceiveStream = .init(receiveQueue: [header.encode()], receiveError: nil)

        connection.receiveUniStream(stream)

        while delegate.receivers.isEmpty {
            await Task.yield()
        }

        #expect(delegate.receivers.count == 1)
        #expect(delegate.receivers[0].header.subgroupID == .explicit(5))
    }
}
