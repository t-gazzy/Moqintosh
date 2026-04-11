//
//  SubscriberTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct SubscriberTests {

    @Test func subscribeNamespaceSendsMessage() async throws {
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: stream, dispatcher: ControlMessageDispatcher(sessionContext: context))
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)
        let subscriber: Subscriber = session.makeSubscriber()

        let task: Task<Void, Error> = .init {
            try await subscriber.subscribeNamespace(namespacePrefix: TrackNamespace(strings: ["live"]))
        }

        while stream.sentBytes.isEmpty {
            await Task.yield()
        }
        context.requestStore.resolveRequest(with: SubscribeNamespaceOKMessage(requestID: 0))
        try await task.value

        #expect(stream.sentBytes[0].first == UInt8(MessageType.subscribeNamespace.rawValue))
    }

    @Test func subscribeSendsMessage() async throws {
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: stream, dispatcher: ControlMessageDispatcher(sessionContext: context))
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)
        let subscriber: Subscriber = session.makeSubscriber()

        let task: Task<Subscription, Error> = .init {
            try await subscriber.subscribe(
                resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("audio".utf8))
            )
        }

        while stream.sentBytes.isEmpty {
            await Task.yield()
        }
        context.requestStore.resolveSubscribeRequest(
            with: SubscribeOKMessage(
                requestID: 0,
                trackAlias: 1,
                expires: 2,
                groupOrder: .ascending,
                contentExist: .noContent,
                deliveryTimeout: nil,
                maxCacheDuration: nil
            )
        )

        let result: Subscription = try await task.value
        #expect(result.publishedTrack.trackAlias == 1)
        #expect(stream.sentBytes[0].first == UInt8(MessageType.subscribe.rawValue))
    }

    @Test func unsubscribeSendsMessage() async throws {
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: stream, dispatcher: ControlMessageDispatcher(sessionContext: context))
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)
        let subscriber: Subscriber = session.makeSubscriber()
        let subscription: Subscription = Subscription(
            requestID: 6,
            publishedTrack: PublishedTrack(
                requestID: 6,
                resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("audio".utf8)),
                trackAlias: 3,
                groupOrder: .ascending,
                contentExist: .noContent,
                forward: true
            ),
            expires: 0,
            subscriberPriority: 0,
            filter: .largestObject
        )

        try await subscriber.unsubscribe(for: subscription)

        #expect(stream.sentBytes.count == 1)
        #expect(stream.sentBytes[0].first == UInt8(MessageType.unsubscribe.rawValue))
    }

    @Test func fetchSendsMessageAndResolves() async throws {
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: stream, dispatcher: ControlMessageDispatcher(sessionContext: context))
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)
        let subscriber: Subscriber = session.makeSubscriber()
        let resource: TrackResource = TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("audio".utf8))

        let task: Task<FetchSubscription, Error> = .init {
            try await subscriber.fetch(
                resource: resource,
                start: Location(group: 1, object: 2),
                end: Location(group: 3, object: 4)
            )
        }

        while stream.sentBytes.isEmpty {
            await Task.yield()
        }
        context.requestStore.resolveFetchRequest(
            with: FetchOKMessage(
                requestID: 0,
                groupOrder: .ascending,
                endOfTrack: true,
                endLocation: Location(group: 5, object: 6),
                maxCacheDuration: 7
            )
        )

        let result: FetchSubscription = try await task.value
        #expect(result.requestID == 0)
        #expect(result.resource.trackName == Data("audio".utf8))
        #expect(result.groupOrder == .ascending)
        #expect(result.endOfTrack)
        #expect(result.endLocation.group == 5)
        #expect(result.maxCacheDuration == 7)
        #expect(stream.sentBytes[0].first == UInt8(MessageType.fetch.rawValue))
    }

    @Test func fetchCancelSendsMessage() async throws {
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: stream, dispatcher: ControlMessageDispatcher(sessionContext: context))
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)
        let subscriber: Subscriber = session.makeSubscriber()
        let fetchSubscription: FetchSubscription = FetchSubscription(
            requestID: 10,
            resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("audio".utf8)),
            subscriberPriority: 0,
            groupOrder: .ascending,
            endOfTrack: false,
            endLocation: Location(group: 1, object: 2),
            maxCacheDuration: nil
        )

        try await subscriber.fetchCancel(for: fetchSubscription)

        #expect(stream.sentBytes.count == 1)
        #expect(stream.sentBytes[0].first == UInt8(MessageType.fetchCancel.rawValue))
    }

    @Test func joiningRelativeFetchSendsMessageAndResolves() async throws {
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: stream, dispatcher: ControlMessageDispatcher(sessionContext: context))
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)
        let subscriber: Subscriber = session.makeSubscriber()
        let subscription: Subscription = Subscription(
            requestID: 8,
            publishedTrack: PublishedTrack(
                requestID: 8,
                resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("audio".utf8)),
                trackAlias: 3,
                groupOrder: .ascending,
                contentExist: .noContent,
                forward: true
            ),
            expires: 0,
            subscriberPriority: 1,
            filter: .largestObject
        )

        let task: Task<FetchSubscription, Error> = .init {
            try await subscriber.fetch(joining: subscription, startGroupOffset: 5)
        }

        while stream.sentBytes.isEmpty {
            await Task.yield()
        }
        context.requestStore.resolveFetchRequest(
            with: FetchOKMessage(
                requestID: 0,
                groupOrder: .ascending,
                endOfTrack: false,
                endLocation: Location(group: 9, object: 10),
                maxCacheDuration: nil
            )
        )

        let result: FetchSubscription = try await task.value
        let message: FetchMessage = try .decode(from: Data(stream.sentBytes[0].dropFirst(3)))

        #expect(result.requestID == 0)
        guard case .joiningRelative(let joiningRequestID, let startGroupOffset) = message.mode else {
            Issue.record("Expected joining relative fetch")
            return
        }
        #expect(joiningRequestID == 8)
        #expect(startGroupOffset == 5)
    }

    @Test func joiningAbsoluteFetchSendsMessageAndResolves() async throws {
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: stream, dispatcher: ControlMessageDispatcher(sessionContext: context))
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)
        let subscriber: Subscriber = session.makeSubscriber()
        let subscription: Subscription = Subscription(
            requestID: 12,
            publishedTrack: PublishedTrack(
                requestID: 12,
                resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("video".utf8)),
                trackAlias: 4,
                groupOrder: .ascending,
                contentExist: .noContent,
                forward: true
            ),
            expires: 0,
            subscriberPriority: 1,
            filter: .largestObject
        )

        let task: Task<FetchSubscription, Error> = .init {
            try await subscriber.fetch(joining: subscription, startGroup: 7)
        }

        while stream.sentBytes.isEmpty {
            await Task.yield()
        }
        context.requestStore.resolveFetchRequest(
            with: FetchOKMessage(
                requestID: 0,
                groupOrder: .ascending,
                endOfTrack: true,
                endLocation: Location(group: 11, object: 12),
                maxCacheDuration: nil
            )
        )

        let result: FetchSubscription = try await task.value
        let message: FetchMessage = try .decode(from: Data(stream.sentBytes[0].dropFirst(3)))

        #expect(result.requestID == 0)
        guard case .joiningAbsolute(let joiningRequestID, let startGroup) = message.mode else {
            Issue.record("Expected joining absolute fetch")
            return
        }
        #expect(joiningRequestID == 12)
        #expect(startGroup == 7)
    }

    @Test func trackStatusSendsMessageAndResolves() async throws {
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: stream, dispatcher: ControlMessageDispatcher(sessionContext: context))
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)
        let subscriber: Subscriber = session.makeSubscriber()

        let task: Task<TrackStatus, Error> = .init {
            try await subscriber.trackStatus(
                resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("audio".utf8))
            )
        }

        while stream.sentBytes.isEmpty {
            await Task.yield()
        }
        context.requestStore.resolveTrackStatusRequest(
            with: TrackStatusOKMessage(
                requestID: 0,
                trackStatus: TrackStatus(
                    expires: 2,
                    groupOrder: .ascending,
                    contentExist: .noContent,
                    deliveryTimeout: nil,
                    maxCacheDuration: nil
                )
            )
        )

        let result: TrackStatus = try await task.value
        #expect(result.expires == 2)
        #expect(stream.sentBytes[0].first == UInt8(MessageType.trackStatus.rawValue))
    }
}
