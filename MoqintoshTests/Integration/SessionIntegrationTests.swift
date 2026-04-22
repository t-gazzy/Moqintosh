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

    @Test func inboundPublishNamespaceRemainsAccessibleAfterAsyncHandoff() async throws {
        let (session, _, controlStream): (Session, MockTransportConnection, MockTransportBiStream) = try await makeConnectedSession()
        let delegate: TestSessionDelegate = TestSessionDelegate()
        session.delegate = delegate

        controlStream.enqueueReceive(
            PublishNamespaceMessage(
                requestID: 2,
                trackNamespace: TrackNamespace(strings: ["Pad"])
            ).encode()
        )

        let isWaitingForPublishNamespace: Bool = true
        while isWaitingForPublishNamespace && (delegate.receivedPublishNamespace == nil || controlStream.sentBytes.count < 2) {
            await Task.yield()
        }

        controlStream.enqueueReceive(
            SubscribeNamespaceMessage(
                requestID: 4,
                namespacePrefix: TrackNamespace(strings: ["Phone"])
            ).encode()
        )

        while controlStream.sentBytes.count < 3 {
            await Task.yield()
        }

        let receivedNamespace: TrackNamespace = try #require(delegate.receivedPublishNamespace)
        let task: Task<String, Never> = Task {
            receivedNamespace.joinedUTF8Elements()
        }

        let namespaceText: String = await task.value
        controlStream.finishReceiving(with: CancellationError())

        #expect(namespaceText == "Pad")
        #expect(controlStream.sentBytes[2].first == UInt8(MessageType.subscribeNamespaceOK.rawValue))
    }

    @Test func inboundSubscribeDispatchesToSessionDelegateAndSendsError() async throws {
        let (session, _, controlStream): (Session, MockTransportConnection, MockTransportBiStream) = try await makeConnectedSession()
        let delegate: TestSessionDelegate = TestSessionDelegate()
        delegate.subscribeError = SubscribeRequestError(
            code: .trackDoesNotExist,
            reason: "Track does not exist"
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
        let header: SubgroupHeader = SubgroupHeader(trackAlias: 3, groupID: 5, subgroupID: .explicit(7), publisherPriority: 9)
        let object: SubgroupObject = header.makeObject(objectID: 0, content: .payload(ReadOnlyBytes(Data("abc".utf8))))
        let stream: MockTransportUniReceiveStream = MockTransportUniReceiveStream(
            receiveQueue: [
                TransportUniReceiveResult(bytes: header.encode(), isComplete: false),
                TransportUniReceiveResult(bytes: object.encode(), isComplete: true)
            ],
            receiveError: nil
        )

        connection.receiveUniStream(stream)

        guard let streamReceiver: StreamReceiver = await factory.accept() else {
            Issue.record("Expected stream receiver")
            return
        }
        let receivedObject: SubgroupObject? = try await streamReceiver.receive()
        let closedObject: SubgroupObject? = try await streamReceiver.receive()
        controlStream.finishReceiving(with: CancellationError())

        #expect(closedObject == nil)
        #expect(receivedObject?.groupID == 5)
        #expect(receivedObject?.objectID == 0)
        if case .payload(let payload) = receivedObject?.content {
            #expect(payload.equals(Data("abc".utf8)))
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

        connection.receiveDatagram(
            bytes: ObjectDatagram(
                trackAlias: 6,
                groupID: 8,
                objectID: .explicit(10),
                publisherPriority: 12,
                content: .payload(ReadOnlyBytes(Data("xyz".utf8)))
            ).encode()
        )

        let receivedDatagram: ObjectDatagram? = await receiver.receive()
        controlStream.finishReceiving(with: CancellationError())

        #expect(receivedDatagram?.groupID == 8)
        if case .explicit(let objectID) = receivedDatagram?.objectID {
            #expect(objectID == 10)
        } else {
            Issue.record("Expected explicit object ID")
        }
        if case .payload(let payload) = receivedDatagram?.content {
            #expect(payload.equals(Data("xyz".utf8)))
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
        let stream: MockTransportUniReceiveStream = MockTransportUniReceiveStream(
            receiveQueue: [
                TransportUniReceiveResult(
                    bytes: FetchHeader(requestID: fetchSubscription.requestID).encode(),
                    isComplete: false
                ),
                TransportUniReceiveResult(
                    bytes: makeFetchObjectPayload(payload: Data("abc".utf8)),
                    isComplete: true
                )
            ],
            receiveError: nil
        )

        connection.receiveUniStream(stream)

        guard let fetchReceiver: FetchReceiver = await factory.accept() else {
            Issue.record("Expected fetch receiver")
            return
        }
        let receivedObject: SubgroupObject? = try await fetchReceiver.receive()
        let closedObject: SubgroupObject? = try await fetchReceiver.receive()
        controlStream.finishReceiving(with: CancellationError())

        #expect(closedObject == nil)
        #expect(receivedObject?.groupID == 4)
        #expect(receivedObject?.objectID == 6)
        if case .payload(let payload) = receivedObject?.content {
            #expect(payload.equals(Data("abc".utf8)))
        } else {
            Issue.record("Expected payload content")
        }
    }

    @Test func inboundJoiningRelativeFetchDispatchesToSessionDelegateAndSendsOK() async throws {
        let (session, _, controlStream): (Session, MockTransportConnection, MockTransportBiStream) = try await makeConnectedSession()
        let delegate: TestSessionDelegate = TestSessionDelegate()
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
    ServerSetupMessage(
        selectedVersion: 0xff00000E,
        parameters: [
            .maxRequestId(10),
            .moqtImplementation("Mock")
        ]
    )
}

// Safe because the boxed session is only used from a single test-created task.
private struct IntegrationSessionBox: @unchecked Sendable {
    let session: Session
}

private func performSubscribe(
    session: Session,
    controlStream: MockTransportBiStream,
    trackAlias: UInt64
) async throws -> Subscription {
    let sessionBox: IntegrationSessionBox = IntegrationSessionBox(session: session)
    let task: Task<Subscription, Error> = Task {
        try await sessionBox.session.makeSubscriber().subscribe(
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
    let sessionBox: IntegrationSessionBox = IntegrationSessionBox(session: session)
    let task: Task<FetchSubscription, Error> = Task {
        try await sessionBox.session.makeSubscriber().fetch(
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
