//
//  ControlMessageDispatcherTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct ControlMessageDispatcherTests {

    @Test func handlePublishNamespaceSendsOKWhenDelegateAccepts() async {
        let stream: MockTransportBiStream = .init()
        let context: SessionContext = .init(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let dispatcher: ControlMessageDispatcher = .init(sessionContext: context)
        let session: Session = .init(
            sessionContext: context,
            controlMessageReceiver: .init(controlStream: stream, dispatcher: dispatcher)
        )
        let delegate: TestSessionDelegate = .init()
        delegate.publishNamespaceResult = true
        session.delegate = delegate

        await dispatcher.handle(
            .publishNamespace(
                .init(
                    requestID: 2,
                    trackNamespace: .init(strings: ["live"]),
                    authorizationTokens: [.init(value: Data([0x01]))]
                )
            )
        )

        #expect(delegate.receivedPublishNamespace?.elements == [Data("live".utf8)])
        #expect(delegate.receivedPublishNamespaceAuthorizationToken?.value == Data([0x01]))
        #expect(stream.sentBytes.count == 1)
        #expect(stream.sentBytes[0].first == UInt8(MessageType.publishNamespaceOK.rawValue))
    }

    @Test func handleSubscribeSendsErrorWhenDelegateRejects() async {
        let stream: MockTransportBiStream = .init()
        let context: SessionContext = .init(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let dispatcher: ControlMessageDispatcher = .init(sessionContext: context)
        let session: Session = .init(
            sessionContext: context,
            controlMessageReceiver: .init(controlStream: stream, dispatcher: dispatcher)
        )
        let delegate: TestSessionDelegate = .init()
        delegate.subscribeResult = false
        session.delegate = delegate

        await dispatcher.handle(
            .subscribe(
                .init(
                    requestID: 4,
                    resource: .init(trackNamespace: .init(strings: ["live"]), trackName: Data("video".utf8)),
                    subscriberPriority: 1,
                    groupOrder: .publisherDefault,
                    forward: true,
                    filter: .largestObject,
                    deliveryTimeout: nil
                )
            )
        )

        #expect(delegate.receivedSubscribeTrack?.resource.trackName == Data("video".utf8))
        #expect(delegate.receivedSubscribeTrack?.trackAlias == 0)
        #expect(stream.sentBytes.count == 1)
        #expect(stream.sentBytes[0].first == UInt8(MessageType.subscribeError.rawValue))
    }

    @Test func handleTrackStatusSendsOKWhenDelegateReturnsStatus() async {
        let stream: MockTransportBiStream = .init()
        let context: SessionContext = .init(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let dispatcher: ControlMessageDispatcher = .init(sessionContext: context)
        let session: Session = .init(
            sessionContext: context,
            controlMessageReceiver: .init(controlStream: stream, dispatcher: dispatcher)
        )
        let delegate: TestSessionDelegate = .init()
        delegate.trackStatusResult = .init(
            expires: 5,
            groupOrder: .ascending,
            contentExist: .noContent,
            deliveryTimeout: nil,
            maxCacheDuration: nil
        )
        session.delegate = delegate

        await dispatcher.handle(
            .trackStatus(
                .init(
                    requestID: 8,
                    resource: .init(trackNamespace: .init(strings: ["live"]), trackName: Data("video".utf8)),
                    subscriberPriority: 1,
                    groupOrder: .ascending,
                    forward: true,
                    filter: .largestObject
                )
            )
        )

        #expect(delegate.receivedTrackStatusRequest?.requestID == 8)
        #expect(stream.sentBytes.count == 1)
        #expect(stream.sentBytes[0].first == UInt8(MessageType.trackStatusOK.rawValue))
    }

    @Test func handleGoAwayDispatchesToDelegate() async {
        let stream: MockTransportBiStream = .init()
        let context: SessionContext = .init(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let dispatcher: ControlMessageDispatcher = .init(sessionContext: context)
        let session: Session = .init(
            sessionContext: context,
            controlMessageReceiver: .init(controlStream: stream, dispatcher: dispatcher)
        )
        let delegate: TestSessionDelegate = .init()
        session.delegate = delegate

        await dispatcher.handle(.goaway(.init(newSessionURI: "https://example.com")))

        #expect(delegate.receivedGoAwayURI == "https://example.com")
    }
}
