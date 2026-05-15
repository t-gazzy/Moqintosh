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
        let datagramReceiver: DatagramReceiver = session.makeSubscriber().makeDatagramReceiver(for: subscription)
        let datagram: ObjectDatagram = ObjectDatagram(
            trackAlias: 7,
            groupID: 4,
            objectID: .explicit(5),
            publisherPriority: 6,
            content: .payload(ReadOnlyBytes(Data("abc".utf8)))
        )

        var iterator: AsyncStream<ObjectDatagram>.Iterator = datagramReceiver.datagrams.makeAsyncIterator()
        connection.receiveDatagram(bytes: datagram.encode())

        let receivedDatagram: ObjectDatagram? = await iterator.next()

        #expect(receivedDatagram?.groupID == 4)
        if case .payload(let payload) = receivedDatagram?.content {
            #expect(payload.equals(Data("abc".utf8)))
        } else {
            Issue.record("Expected payload content")
        }
    }

    @Test func datagramsStreamYieldsInboundDatagram() async throws {
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
        let datagramReceiver: DatagramReceiver = session.makeSubscriber().makeDatagramReceiver(for: subscription)
        var iterator: AsyncStream<ObjectDatagram>.Iterator = datagramReceiver.datagrams.makeAsyncIterator()
        let datagram: ObjectDatagram = ObjectDatagram(
            trackAlias: 7,
            groupID: 8,
            objectID: .explicit(9),
            publisherPriority: 10,
            content: .payload(ReadOnlyBytes(Data("stream".utf8)))
        )

        connection.receiveDatagram(bytes: datagram.encode())

        let receivedDatagram: ObjectDatagram? = await iterator.next()

        #expect(receivedDatagram?.groupID == 8)
        if case .payload(let payload) = receivedDatagram?.content {
            #expect(payload.equals(Data("stream".utf8)))
        } else {
            Issue.record("Expected payload content")
        }
    }

    @Test func datagramsStreamReturnsNilWhenCancelled() async throws {
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
        let datagramReceiver: DatagramReceiver = session.makeSubscriber().makeDatagramReceiver(for: subscription)

        let datagrams: AsyncStream<ObjectDatagram> = datagramReceiver.datagrams
        let receiveTask: Task<ObjectDatagram?, Never> = Task {
            var iterator: AsyncStream<ObjectDatagram>.Iterator = datagrams.makeAsyncIterator()
            return await iterator.next()
        }
        receiveTask.cancel()

        let receivedDatagram: ObjectDatagram? = await receiveTask.value

        #expect(receivedDatagram == nil)
    }
}
