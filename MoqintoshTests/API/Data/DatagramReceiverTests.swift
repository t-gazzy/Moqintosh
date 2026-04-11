//
//  DatagramReceiverTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct DatagramReceiverTests {

    @Test func inboundDatagramNotifiesDelegate() async throws {
        let controlStream: MockTransportBiStream = MockTransportBiStream()
        let connection: MockTransportConnection = MockTransportConnection(biStream: controlStream)
        let context: SessionContext = SessionContext(connection: connection, controlStream: controlStream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: controlStream, dispatcher: ControlMessageDispatcher(sessionContext: context))
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)
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
        let datagramReceiver: DatagramReceiver = session.makeSubscriber().makeDatagramReceiver(for: subscription)
        let delegate: TestDatagramReceiverDelegate = TestDatagramReceiverDelegate()
        datagramReceiver.delegate = delegate
        let datagram: ObjectDatagram = ObjectDatagram(
            trackAlias: 7,
            groupID: 4,
            objectID: .explicit(5),
            publisherPriority: 6,
            content: .payload(Data("abc".utf8))
        )

        connection.receiveDatagram(bytes: datagram.encode())

        while delegate.receivedDatagrams.isEmpty {
            await Task.yield()
        }

        #expect(delegate.receivedDatagrams.count == 1)
        #expect(delegate.receivedDatagrams[0].groupID == 4)
        if case .payload(let payload) = delegate.receivedDatagrams[0].content {
            #expect(payload == Data("abc".utf8))
        } else {
            Issue.record("Expected payload content")
        }
    }
}
