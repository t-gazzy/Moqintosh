//
//  SessionTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Testing
@testable import Moqintosh

struct SessionTests {

    @Test func makePublisherReturnsPublisherBoundToSession() {
        let stream: MockTransportBiStream = .init()
        let context: SessionContext = .init(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let receiver: ControlMessageReceiver = .init(controlStream: stream, dispatcher: .init(sessionContext: context))
        let session: Session = .init(sessionContext: context, controlMessageReceiver: receiver)

        let publisher: Publisher = session.makePublisher()

        #expect(publisher.session === session)
    }

    @Test func makeSubscriberReturnsSubscriberBoundToSession() {
        let stream: MockTransportBiStream = .init()
        let context: SessionContext = .init(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let receiver: ControlMessageReceiver = .init(controlStream: stream, dispatcher: .init(sessionContext: context))
        let session: Session = .init(sessionContext: context, controlMessageReceiver: receiver)

        let subscriber: Subscriber = session.makeSubscriber()

        #expect(subscriber.session === session)
    }
}
