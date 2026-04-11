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
        let controlStream: MockTransportBiStream = MockTransportBiStream(receiveQueue: [makeServerSetupMessage().encode()])
        let connection: MockTransportConnection = MockTransportConnection(biStream: controlStream)
        let endpoint: MockTransportEndpoint = MockTransportEndpoint(connection: connection)

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
            try await publisher.publishNamespace(trackNamespace: TrackNamespace(strings: ["live"]))
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
                resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("video".utf8))
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

    @Test func fetchRoundTripResolves() async throws {
        let (session, _, controlStream): (Session, MockTransportConnection, MockTransportBiStream) = try await makeConnectedSession()
        let subscriber: Subscriber = session.makeSubscriber()

        let task: Task<FetchSubscription, Error> = .init {
            try await subscriber.fetch(
                resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("video".utf8)),
                start: Location(group: 1, object: 2),
                end: Location(group: 3, object: 4)
            )
        }

        while controlStream.sentBytes.count < 2 {
            await Task.yield()
        }
        controlStream.enqueueReceive(
            FetchOKMessage(
                requestID: 0,
                groupOrder: .ascending,
                endOfTrack: true,
                endLocation: Location(group: 5, object: 6),
                maxCacheDuration: 7
            ).encode()
        )

        let fetchSubscription: FetchSubscription = try await task.value
        controlStream.finishReceiving(with: CancellationError())

        #expect(fetchSubscription.requestID == 0)
        #expect(fetchSubscription.endOfTrack)
        #expect(fetchSubscription.endLocation.group == 5)
        #expect(controlStream.sentBytes[1].first == UInt8(MessageType.fetch.rawValue))
    }

    @Test func joiningRelativeFetchRoundTripResolves() async throws {
        let (session, _, controlStream): (Session, MockTransportConnection, MockTransportBiStream) = try await makeConnectedSession()
        let subscription: Subscription = try await performSubscribe(
            session: session,
            controlStream: controlStream,
            trackAlias: 3
        )
        let subscriber: Subscriber = session.makeSubscriber()

        let task: Task<FetchSubscription, Error> = .init {
            try await subscriber.fetch(joining: subscription, startGroupOffset: 5)
        }

        while controlStream.sentBytes.count < 3 {
            await Task.yield()
        }
        controlStream.enqueueReceive(
            FetchOKMessage(
                requestID: 2,
                groupOrder: .ascending,
                endOfTrack: false,
                endLocation: Location(group: 6, object: 7),
                maxCacheDuration: nil
            ).encode()
        )

        let fetchSubscription: FetchSubscription = try await task.value
        controlStream.finishReceiving(with: CancellationError())

        #expect(fetchSubscription.requestID == 2)
        let message: FetchMessage = try .decode(from: Data(controlStream.sentBytes[2].dropFirst(3)))
        guard case .joiningRelative(let joiningRequestID, let startGroupOffset) = message.mode else {
            Issue.record("Expected joining relative fetch")
            return
        }
        #expect(joiningRequestID == 0)
        #expect(startGroupOffset == 5)
    }

    @Test func joiningAbsoluteFetchRoundTripResolves() async throws {
        let (session, _, controlStream): (Session, MockTransportConnection, MockTransportBiStream) = try await makeConnectedSession()
        let subscription: Subscription = try await performSubscribe(
            session: session,
            controlStream: controlStream,
            trackAlias: 3
        )
        let subscriber: Subscriber = session.makeSubscriber()

        let task: Task<FetchSubscription, Error> = .init {
            try await subscriber.fetch(joining: subscription, startGroup: 7)
        }

        while controlStream.sentBytes.count < 3 {
            await Task.yield()
        }
        controlStream.enqueueReceive(
            FetchOKMessage(
                requestID: 2,
                groupOrder: .ascending,
                endOfTrack: false,
                endLocation: Location(group: 8, object: 9),
                maxCacheDuration: nil
            ).encode()
        )

        let fetchSubscription: FetchSubscription = try await task.value
        controlStream.finishReceiving(with: CancellationError())

        #expect(fetchSubscription.requestID == 2)
        let message: FetchMessage = try .decode(from: Data(controlStream.sentBytes[2].dropFirst(3)))
        guard case .joiningAbsolute(let joiningRequestID, let startGroup) = message.mode else {
            Issue.record("Expected joining absolute fetch")
            return
        }
        #expect(joiningRequestID == 0)
        #expect(startGroup == 7)
    }

    @Test func inboundPublishNamespaceDispatchesToSessionDelegateAndSendsOK() async throws {
        let (session, _, controlStream): (Session, MockTransportConnection, MockTransportBiStream) = try await makeConnectedSession()
        let delegate: TestSessionDelegate = TestSessionDelegate()
        delegate.publishNamespaceResult = true
        session.delegate = delegate

        controlStream.enqueueReceive(
            PublishNamespaceMessage(
                requestID: 2,
                trackNamespace: TrackNamespace(strings: ["live"])
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
        let delegate: TestSessionDelegate = TestSessionDelegate()
        delegate.subscribeResult = false
        session.delegate = delegate

        controlStream.enqueueReceive(
            SubscribeMessage(
                requestID: 4,
                resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("audio".utf8)),
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
        let delegate: IntegrationStreamDelegate = IntegrationStreamDelegate()
        factory.delegate = delegate
        let header: SubgroupHeader = SubgroupHeader(trackAlias: 3, groupID: 5, subgroupID: .explicit(7), publisherPriority: 9)
        let object: SubgroupObject = header.makeObject(objectID: 0, content: .payload(Data("abc".utf8)))
        let stream: MockTransportUniReceiveStream = MockTransportUniReceiveStream(
            receiveQueue: [
                .init(bytes: header.encode(), isComplete: false),
                .init(bytes: object.encode(), isComplete: true)
            ],
            receiveError: nil
        )

        connection.receiveUniStream(stream)

        while delegate.receivedObjects.isEmpty {
            await Task.yield()
        }
        while delegate.closedReceiverCount < 1 {
            await Task.yield()
        }
        controlStream.finishReceiving(with: CancellationError())

        #expect(delegate.receivedObjects.count == 1)
        #expect(delegate.closedReceiverCount == 1)
        #expect(delegate.receivedObjects[0].groupID == 5)
        #expect(delegate.receivedObjects[0].objectID == 0)
        if case .payload(let payload) = delegate.receivedObjects[0].content {
            #expect(payload == Data("abc".utf8))
        } else {
            Issue.record("Expected payload content")
        }
    }

    @Test func subscribedDatagramRoutesInboundDatagram() async throws {
        let (session, connection, controlStream): (Session, MockTransportConnection, MockTransportBiStream) = try await makeConnectedSession()
        let subscription: Subscription = try await performSubscribe(
            session: session,
            controlStream: controlStream,
            trackAlias: 6
        )
        let receiver: DatagramReceiver = session.makeSubscriber().makeDatagramReceiver(for: subscription)
        let delegate: TestDatagramReceiverDelegate = TestDatagramReceiverDelegate()
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
        if case .explicit(let objectID) = delegate.receivedDatagrams[0].objectID {
            #expect(objectID == 10)
        } else {
            Issue.record("Expected explicit object ID")
        }
        if case .payload(let payload) = delegate.receivedDatagrams[0].content {
            #expect(payload == Data("xyz".utf8))
        } else {
            Issue.record("Expected payload content")
        }
    }

    @Test func fetchedStreamRoutesInboundObject() async throws {
        let (session, connection, controlStream): (Session, MockTransportConnection, MockTransportBiStream) = try await makeConnectedSession()
        let fetchSubscription: FetchSubscription = try await performFetch(
            session: session,
            controlStream: controlStream
        )
        let factory: FetchReceiverFactory = session.makeSubscriber().makeFetchReceiverFactory(for: fetchSubscription)
        let delegate: TestFetchIntegrationDelegate = TestFetchIntegrationDelegate()
        factory.delegate = delegate
        let stream: MockTransportUniReceiveStream = MockTransportUniReceiveStream(
            receiveQueue: [
                .init(bytes: FetchHeader(requestID: fetchSubscription.requestID).encode(), isComplete: false),
                .init(bytes: makeFetchObjectPayload(payload: Data("abc".utf8)), isComplete: true)
            ],
            receiveError: nil
        )

        connection.receiveUniStream(stream)

        while delegate.receivedObjects.isEmpty {
            await Task.yield()
        }
        while delegate.closedReceiverCount < 1 {
            await Task.yield()
        }
        controlStream.finishReceiving(with: CancellationError())

        #expect(delegate.receivedObjects.count == 1)
        #expect(delegate.closedReceiverCount == 1)
        #expect(delegate.receivedObjects[0].groupID == 4)
        #expect(delegate.receivedObjects[0].objectID == 6)
        if case .payload(let payload) = delegate.receivedObjects[0].content {
            #expect(payload == Data("abc".utf8))
        } else {
            Issue.record("Expected payload content")
        }
    }

    @Test func inboundJoiningRelativeFetchDispatchesToSessionDelegateAndSendsOK() async throws {
        let (session, _, controlStream): (Session, MockTransportConnection, MockTransportBiStream) = try await makeConnectedSession()
        let delegate: TestSessionDelegate = TestSessionDelegate()
        delegate.subscribeResult = true
        delegate.fetchResponse = FetchResponse(
            groupOrder: .ascending,
            endOfTrack: false,
            endLocation: Location(group: 8, object: 9),
            maxCacheDuration: nil
        )
        session.delegate = delegate

        controlStream.enqueueReceive(
            SubscribeMessage(
                requestID: 4,
                resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("audio".utf8)),
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

        controlStream.enqueueReceive(
            FetchMessage(
                requestID: 6,
                subscriberPriority: 2,
                groupOrder: .ascending,
                mode: .joiningRelative(joiningRequestID: 4, startGroupOffset: 3)
            ).encode()
        )

        while controlStream.sentBytes.count < 3 {
            await Task.yield()
        }
        controlStream.finishReceiving(with: CancellationError())

        guard case .joiningRelative(
            let requestID,
            let joiningRequestID,
            let resource,
            let subscriberPriority,
            let groupOrder,
            let startGroupOffset
        ) = delegate.receivedFetchRequest else {
            Issue.record("Expected joining relative fetch request")
            return
        }
        #expect(requestID == 6)
        #expect(joiningRequestID == 4)
        #expect(resource.trackName == Data("audio".utf8))
        #expect(subscriberPriority == 2)
        #expect(groupOrder == .ascending)
        #expect(startGroupOffset == 3)
        #expect(controlStream.sentBytes[2].first == UInt8(MessageType.fetchOK.rawValue))
    }

    @Test func inboundJoiningAbsoluteFetchDispatchesToSessionDelegateAndSendsOK() async throws {
        let (session, _, controlStream): (Session, MockTransportConnection, MockTransportBiStream) = try await makeConnectedSession()
        let delegate: TestSessionDelegate = TestSessionDelegate()
        delegate.subscribeResult = true
        delegate.fetchResponse = FetchResponse(
            groupOrder: .ascending,
            endOfTrack: false,
            endLocation: Location(group: 10, object: 11),
            maxCacheDuration: nil
        )
        session.delegate = delegate

        controlStream.enqueueReceive(
            SubscribeMessage(
                requestID: 4,
                resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("audio".utf8)),
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

        controlStream.enqueueReceive(
            FetchMessage(
                requestID: 6,
                subscriberPriority: 2,
                groupOrder: .ascending,
                mode: .joiningAbsolute(joiningRequestID: 4, startGroup: 5)
            ).encode()
        )

        while controlStream.sentBytes.count < 3 {
            await Task.yield()
        }
        controlStream.finishReceiving(with: CancellationError())

        guard case .joiningAbsolute(
            let requestID,
            let joiningRequestID,
            let resource,
            let subscriberPriority,
            let groupOrder,
            let startGroup
        ) = delegate.receivedFetchRequest else {
            Issue.record("Expected joining absolute fetch request")
            return
        }
        #expect(requestID == 6)
        #expect(joiningRequestID == 4)
        #expect(resource.trackName == Data("audio".utf8))
        #expect(subscriberPriority == 2)
        #expect(groupOrder == .ascending)
        #expect(startGroup == 5)
        #expect(controlStream.sentBytes[2].first == UInt8(MessageType.fetchOK.rawValue))
    }
}

private final class IntegrationStreamDelegate: StreamReceiverFactoryDelegate, StreamReceiverDelegate {

    private(set) var receivers: [StreamReceiver]
    private(set) var receivedObjects: [SubgroupObject]
    private(set) var closedReceiverCount: Int

    init() {
        self.receivers = []
        self.receivedObjects = []
        self.closedReceiverCount = 0
    }

    func streamReceiverFactory(_ factory: StreamReceiverFactory, didCreate receiver: StreamReceiver) {
        receiver.delegate = self
        receivers.append(receiver)
    }

    func streamReceiver(_ receiver: StreamReceiver, didReceive object: SubgroupObject) {
        receivedObjects.append(object)
    }

    func streamReceiverDidClose(_ receiver: StreamReceiver) {
        closedReceiverCount += 1
    }
}

private func makeConnectedSession() async throws -> (Session, MockTransportConnection, MockTransportBiStream) {
    let controlStream: MockTransportBiStream = MockTransportBiStream(
        receiveQueue: [makeServerSetupMessage().encode()],
        receiveError: nil
    )
    let connection: MockTransportConnection = MockTransportConnection(biStream: controlStream)
    let endpoint: MockTransportEndpoint = MockTransportEndpoint(connection: connection)
    let session: Session = try await SessionFactory().connect(transportEndpoint: endpoint)
    return (session, connection, controlStream)
}

private func makeServerSetupMessage() -> ServerSetupMessage {
    .init(
        selectedVersion: 0xff00000E,
        parameters: [
            .maxRequestId(10),
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
            resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("media".utf8))
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

private func performFetch(
    session: Session,
    controlStream: MockTransportBiStream
) async throws -> FetchSubscription {
    let subscriber: Subscriber = session.makeSubscriber()
    let task: Task<FetchSubscription, Error> = .init {
        try await subscriber.fetch(
            resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("media".utf8)),
            start: Location(group: 1, object: 2),
            end: Location(group: 3, object: 4)
        )
    }

    while controlStream.sentBytes.count < 2 {
        await Task.yield()
    }
    controlStream.enqueueReceive(
        FetchOKMessage(
            requestID: 0,
            groupOrder: .ascending,
            endOfTrack: true,
            endLocation: Location(group: 5, object: 6),
            maxCacheDuration: nil
        ).encode()
    )

    return try await task.value
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
