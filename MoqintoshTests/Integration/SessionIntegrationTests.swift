//
//  SessionIntegrationTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct SessionIntegrationTests {

    @Test func connectCreatesSessionOverMockTransport() async throws {
        let controlStream: MockTransportBiStream = .init(receiveQueue: [makeServerSetupMessage().encode()])
        let connection: MockTransportConnection = .init(biStream: controlStream)
        let endpoint: MockTransportEndpoint = .init(connection: connection)

        let session: Session = try await SessionFactory().connect(transportEndpoint: endpoint)

        #expect(type(of: session) == Session.self)
        #expect(endpoint.connectCallCount == 1)
        #expect(controlStream.sentBytes.count == 1)
        #expect(controlStream.sentBytes[0].first == UInt8(MessageType.clientSetup.rawValue))
    }

    @Test func publishNamespaceRoundTripResolves() async throws {
        let (session, _, controlStream): (Session, MockTransportConnection, MockTransportBiStream) = try await makeConnectedSession()
        let publisher: Publisher = session.makePublisher()

        let task: Task<Void, Error> = .init {
            try await publisher.publishNamespace(trackNamespace: .init(strings: ["live"]))
        }

        while controlStream.sentBytes.count < 2 {
            await Task.yield()
        }
        controlStream.enqueueReceive(PublishNamespaceOKMessage(requestID: 0).encode())

        try await task.value
        controlStream.finishReceiving(with: CancellationError())

        #expect(controlStream.sentBytes[1].first == UInt8(MessageType.publishNamespace.rawValue))
    }

    @Test func subscribeRoundTripResolves() async throws {
        let (session, _, controlStream): (Session, MockTransportConnection, MockTransportBiStream) = try await makeConnectedSession()
        let subscriber: Subscriber = session.makeSubscriber()

        let task: Task<Subscription, Error> = .init {
            try await subscriber.subscribe(
                resource: .init(trackNamespace: .init(strings: ["live"]), trackName: Data("video".utf8))
            )
        }

        while controlStream.sentBytes.count < 2 {
            await Task.yield()
        }
        controlStream.enqueueReceive(
            SubscribeOKMessage(
                requestID: 0,
                trackAlias: 1,
                expires: 2,
                groupOrder: .ascending,
                contentExist: .noContent,
                deliveryTimeout: nil,
                maxCacheDuration: nil
            ).encode()
        )

        let subscription: Subscription = try await task.value
        controlStream.finishReceiving(with: CancellationError())

        #expect(subscription.publishedTrack.trackAlias == 1)
        #expect(controlStream.sentBytes[1].first == UInt8(MessageType.subscribe.rawValue))
    }

    @Test func inboundPublishNamespaceDispatchesToSessionDelegateAndSendsOK() async throws {
        let (session, _, controlStream): (Session, MockTransportConnection, MockTransportBiStream) = try await makeConnectedSession()
        let delegate: TestSessionDelegate = .init()
        delegate.publishNamespaceResult = true
        session.delegate = delegate

        controlStream.enqueueReceive(
            PublishNamespaceMessage(
                requestID: 2,
                trackNamespace: .init(strings: ["live"])
            ).encode()
        )

        while controlStream.sentBytes.count < 2 {
            await Task.yield()
        }
        controlStream.finishReceiving(with: CancellationError())

        #expect(delegate.receivedPublishNamespace?.elements == [Data("live".utf8)])
        #expect(controlStream.sentBytes[1].first == UInt8(MessageType.publishNamespaceOK.rawValue))
    }

    @Test func inboundSubscribeDispatchesToSessionDelegateAndSendsError() async throws {
        let (session, _, controlStream): (Session, MockTransportConnection, MockTransportBiStream) = try await makeConnectedSession()
        let delegate: TestSessionDelegate = .init()
        delegate.subscribeResult = false
        session.delegate = delegate

        controlStream.enqueueReceive(
            SubscribeMessage(
                requestID: 4,
                resource: .init(trackNamespace: .init(strings: ["live"]), trackName: Data("audio".utf8)),
                subscriberPriority: 1,
                groupOrder: .ascending,
                forward: true,
                filter: .largestObject,
                deliveryTimeout: nil
            ).encode()
        )

        while controlStream.sentBytes.count < 2 {
            await Task.yield()
        }
        controlStream.finishReceiving(with: CancellationError())

        #expect(delegate.receivedSubscribeTrack?.resource.trackName == Data("audio".utf8))
        #expect(controlStream.sentBytes[1].first == UInt8(MessageType.subscribeError.rawValue))
    }

    @Test func subscribedStreamRoutesInboundObject() async throws {
        let (session, connection, controlStream): (Session, MockTransportConnection, MockTransportBiStream) = try await makeConnectedSession()
        let subscription: Subscription = try await performSubscribe(
            session: session,
            controlStream: controlStream,
            trackAlias: 3
        )
        let factory: StreamReceiverFactory = session.makeSubscriber().makeStreamReceiverFactory(for: subscription)
        let delegate: IntegrationStreamDelegate = .init()
        factory.delegate = delegate
        let header: SubgroupHeader = .init(trackAlias: 3, groupID: 5, subgroupID: .explicit(7), publisherPriority: 9)
        let object: SubgroupObject = header.makeObject(objectID: 0, content: .payload(Data("abc".utf8)))
        let stream: MockTransportUniReceiveStream = .init(receiveQueue: [header.encode(), object.encode()], receiveError: CancellationError())

        connection.receiveUniStream(stream)

        while delegate.receivedObjects.isEmpty {
            await Task.yield()
        }
        controlStream.finishReceiving(with: CancellationError())

        #expect(delegate.receivedObjects.count == 1)
        #expect(delegate.receivedObjects[0].objectID == 0)
    }

    @Test func subscribedDatagramRoutesInboundDatagram() async throws {
        let (session, connection, controlStream): (Session, MockTransportConnection, MockTransportBiStream) = try await makeConnectedSession()
        let subscription: Subscription = try await performSubscribe(
            session: session,
            controlStream: controlStream,
            trackAlias: 6
        )
        let receiver: DatagramReceiver = session.makeSubscriber().makeDatagramReceiver(for: subscription)
        let delegate: TestDatagramReceiverDelegate = .init()
        receiver.delegate = delegate

        connection.receiveDatagram(
            bytes: ObjectDatagram(
                trackAlias: 6,
                groupID: 8,
                objectID: .explicit(10),
                publisherPriority: 12,
                content: .payload(Data("xyz".utf8))
            ).encode()
        )

        while delegate.receivedDatagrams.isEmpty {
            await Task.yield()
        }
        controlStream.finishReceiving(with: CancellationError())

        #expect(delegate.receivedDatagrams.count == 1)
        #expect(delegate.receivedDatagrams[0].groupID == 8)
    }
}

private final class IntegrationStreamDelegate: StreamReceiverFactoryDelegate, StreamReceiverDelegate {

    private(set) var receivers: [StreamReceiver]
    private(set) var receivedObjects: [SubgroupObject]

    init() {
        self.receivers = []
        self.receivedObjects = []
    }

    func streamReceiverFactory(_ factory: StreamReceiverFactory, didCreate receiver: StreamReceiver) {
        receiver.delegate = self
        receivers.append(receiver)
    }

    func streamReceiver(_ receiver: StreamReceiver, didReceive object: SubgroupObject) {
        receivedObjects.append(object)
    }
}

private func makeConnectedSession() async throws -> (Session, MockTransportConnection, MockTransportBiStream) {
    let controlStream: MockTransportBiStream = .init(
        receiveQueue: [makeServerSetupMessage().encode()],
        receiveError: nil
    )
    let connection: MockTransportConnection = .init(biStream: controlStream)
    let endpoint: MockTransportEndpoint = .init(connection: connection)
    let session: Session = try await SessionFactory().connect(transportEndpoint: endpoint)
    return (session, connection, controlStream)
}

private func makeServerSetupMessage() -> ServerSetupMessage {
    .init(
        selectedVersion: 0xff00000E,
        parameters: [
            .maxRequestId(0),
            .moqtImplementation("Mock")
        ]
    )
}

private func performSubscribe(
    session: Session,
    controlStream: MockTransportBiStream,
    trackAlias: UInt64
) async throws -> Subscription {
    let subscriber: Subscriber = session.makeSubscriber()
    let task: Task<Subscription, Error> = .init {
        try await subscriber.subscribe(
            resource: .init(trackNamespace: .init(strings: ["live"]), trackName: Data("media".utf8))
        )
    }

    while controlStream.sentBytes.count < 2 {
        await Task.yield()
    }
    controlStream.enqueueReceive(
        SubscribeOKMessage(
            requestID: 0,
            trackAlias: trackAlias,
            expires: 2,
            groupOrder: .ascending,
            contentExist: .noContent,
            deliveryTimeout: nil,
            maxCacheDuration: nil
        ).encode()
    )

    return try await task.value
}
