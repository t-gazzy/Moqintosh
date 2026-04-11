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
        let stream: MockTransportBiStream = .init()
        let context: SessionContext = .init(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let receiver: ControlMessageReceiver = .init(controlStream: stream, dispatcher: .init(sessionContext: context))
        let session: Session = .init(sessionContext: context, controlMessageReceiver: receiver)
        let subscriber: Subscriber = session.makeSubscriber()

        let task: Task<Void, Error> = .init {
            try await subscriber.subscribeNamespace(namespacePrefix: .init(strings: ["live"]))
        }

        while stream.sentBytes.isEmpty {
            await Task.yield()
        }
        context.requestStore.resolveRequest(with: SubscribeNamespaceOKMessage(requestID: 0))
        try await task.value

        #expect(stream.sentBytes[0].first == UInt8(MessageType.subscribeNamespace.rawValue))
    }

    @Test func subscribeSendsMessage() async throws {
        let stream: MockTransportBiStream = .init()
        let context: SessionContext = .init(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let receiver: ControlMessageReceiver = .init(controlStream: stream, dispatcher: .init(sessionContext: context))
        let session: Session = .init(sessionContext: context, controlMessageReceiver: receiver)
        let subscriber: Subscriber = session.makeSubscriber()

        let task: Task<Subscription, Error> = .init {
            try await subscriber.subscribe(
                resource: .init(trackNamespace: .init(strings: ["live"]), trackName: Data("audio".utf8))
            )
        }

        while stream.sentBytes.isEmpty {
            await Task.yield()
        }
        context.requestStore.resolveSubscribeRequest(
            with: .init(
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
        let stream: MockTransportBiStream = .init()
        let context: SessionContext = .init(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let receiver: ControlMessageReceiver = .init(controlStream: stream, dispatcher: .init(sessionContext: context))
        let session: Session = .init(sessionContext: context, controlMessageReceiver: receiver)
        let subscriber: Subscriber = session.makeSubscriber()
        let subscription: Subscription = .init(
            requestID: 6,
            publishedTrack: .init(
                requestID: 6,
                resource: .init(trackNamespace: .init(strings: ["live"]), trackName: Data("audio".utf8)),
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

    @Test func trackStatusSendsMessageAndResolves() async throws {
        let stream: MockTransportBiStream = .init()
        let context: SessionContext = .init(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let receiver: ControlMessageReceiver = .init(controlStream: stream, dispatcher: .init(sessionContext: context))
        let session: Session = .init(sessionContext: context, controlMessageReceiver: receiver)
        let subscriber: Subscriber = session.makeSubscriber()

        let task: Task<TrackStatus, Error> = .init {
            try await subscriber.trackStatus(
                resource: .init(trackNamespace: .init(strings: ["live"]), trackName: Data("audio".utf8))
            )
        }

        while stream.sentBytes.isEmpty {
            await Task.yield()
        }
        context.requestStore.resolveTrackStatusRequest(
            with: .init(
                requestID: 0,
                trackStatus: .init(
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
