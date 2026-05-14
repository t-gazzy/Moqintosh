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

    @Test func inboundDatagramYieldsDatagram() async throws {
        let controlStream: MockTransportBiStream = MockTransportBiStream()
        let connection: MockTransportConnection = MockTransportConnection(biStream: controlStream)
        let context: SessionContext = SessionContext(connection: connection, controlStream: controlStream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: controlStream)
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)
        await session.start()
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
        let datagramReceiver: DatagramReceiver = await session.makeSubscriber().makeDatagramReceiver(for: subscription)
        let datagram: ObjectDatagram = ObjectDatagram(
            trackAlias: 7,
            groupID: 4,
            objectID: .explicit(5),
            publisherPriority: 6,
            content: .payload(ReadOnlyBytes(Data("abc".utf8)))
        )

        connection.receiveDatagram(bytes: datagram.encode())

        let receivedDatagram: ObjectDatagram? = await datagramReceiver.receive()

        #expect(receivedDatagram?.groupID == 4)
        if case .payload(let payload) = receivedDatagram?.content {
            #expect(payload.equals(Data("abc".utf8)))
        } else {
            Issue.record("Expected payload content")
        }
    }

    @Test func receiveReturnsNilWhenCancelled() async throws {
        let controlStream: MockTransportBiStream = MockTransportBiStream()
        let connection: MockTransportConnection = MockTransportConnection(biStream: controlStream)
        let context: SessionContext = SessionContext(connection: connection, controlStream: controlStream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: controlStream)
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)
        await session.start()
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
        let datagramReceiver: DatagramReceiver = await session.makeSubscriber().makeDatagramReceiver(for: subscription)

        let receiveTask: Task<ObjectDatagram?, Never> = Task {
            await datagramReceiver.receive()
        }
        receiveTask.cancel()

        let receivedDatagram: ObjectDatagram? = await receiveTask.value

        #expect(receivedDatagram == nil)
    }
}
