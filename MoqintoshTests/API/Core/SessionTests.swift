//
//  SessionTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Testing
@testable import Moqintosh

struct SessionTests {

    @Test func makePublisherReturnsPublisher() {
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: stream)
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)

        let publisher: Publisher = session.makePublisher()

        #expect(type(of: publisher) == Publisher.self)
    }

    @Test func makeSubscriberReturnsSubscriber() {
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: stream)
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)

        let subscriber: Subscriber = session.makeSubscriber()

        #expect(type(of: subscriber) == Subscriber.self)
    }
}
