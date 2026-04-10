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
        context.resolveRequest(with: SubscribeNamespaceOKMessage(requestID: 0))
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
        context.resolveSubscribeRequest(
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
}
