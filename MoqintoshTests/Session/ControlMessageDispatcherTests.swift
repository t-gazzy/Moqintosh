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

    @Test func handleFetchSendsOKWhenDelegateReturnsResponse() async {
        let stream: MockTransportBiStream = .init()
        let context: SessionContext = .init(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let dispatcher: ControlMessageDispatcher = .init(sessionContext: context)
        let session: Session = .init(
            sessionContext: context,
            controlMessageReceiver: .init(controlStream: stream, dispatcher: dispatcher)
        )
        let delegate: TestSessionDelegate = .init()
        delegate.fetchResponse = .init(
            groupOrder: .ascending,
            endOfTrack: true,
            endLocation: .init(group: 7, object: 8),
            maxCacheDuration: 9
        )
        session.delegate = delegate

        await dispatcher.handle(
            .fetch(
                .init(
                    requestID: 10,
                    subscriberPriority: 1,
                    groupOrder: .ascending,
                    mode: .standalone(
                        resource: .init(trackNamespace: .init(strings: ["live"]), trackName: Data("video".utf8)),
                        start: .init(group: 1, object: 2),
                        end: .init(group: 3, object: 4)
                    )
                )
            )
        )

        guard case .standalone(let requestID, let resource, let subscriberPriority, let groupOrder, let start, let end) = delegate.receivedFetchRequest else {
            Issue.record("Expected standalone fetch request")
            return
        }
        #expect(requestID == 10)
        #expect(resource.trackName == Data("video".utf8))
        #expect(subscriberPriority == 1)
        #expect(groupOrder == .ascending)
        #expect(start.group == 1)
        #expect(end.object == 4)
        #expect(stream.sentBytes.count == 1)
        #expect(stream.sentBytes[0].first == UInt8(MessageType.fetchOK.rawValue))
    }

    @Test func handleFetchCancelDispatchesToDelegate() async {
        let stream: MockTransportBiStream = .init()
        let context: SessionContext = .init(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let dispatcher: ControlMessageDispatcher = .init(sessionContext: context)
        let session: Session = .init(
            sessionContext: context,
            controlMessageReceiver: .init(controlStream: stream, dispatcher: dispatcher)
        )
        let delegate: TestSessionDelegate = .init()
        session.delegate = delegate

        await dispatcher.handle(.fetchCancel(.init(requestID: 12)))

        #expect(delegate.receivedFetchCancelRequestID == 12)
    }

    @Test func handleJoiningRelativeFetchSendsOKWhenSubscriptionExists() async {
        let stream: MockTransportBiStream = .init()
        let context: SessionContext = .init(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let dispatcher: ControlMessageDispatcher = .init(sessionContext: context)
        let session: Session = .init(
            sessionContext: context,
            controlMessageReceiver: .init(controlStream: stream, dispatcher: dispatcher)
        )
        let delegate: TestSessionDelegate = .init()
        delegate.fetchResponse = .init(
            groupOrder: .ascending,
            endOfTrack: false,
            endLocation: .init(group: 13, object: 14),
            maxCacheDuration: nil
        )
        session.delegate = delegate
        context.registerInboundSubscriptionResource(
            requestID: 4,
            resource: .init(trackNamespace: .init(strings: ["live"]), trackName: Data("video".utf8))
        )

        await dispatcher.handle(
            .fetch(
                .init(
                    requestID: 10,
                    subscriberPriority: 1,
                    groupOrder: .ascending,
                    mode: .joiningRelative(joiningRequestID: 4, startGroupOffset: 6)
                )
            )
        )

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
        #expect(requestID == 10)
        #expect(joiningRequestID == 4)
        #expect(resource.trackName == Data("video".utf8))
        #expect(subscriberPriority == 1)
        #expect(groupOrder == .ascending)
        #expect(startGroupOffset == 6)
        #expect(stream.sentBytes.count == 1)
        #expect(stream.sentBytes[0].first == UInt8(MessageType.fetchOK.rawValue))
    }

    @Test func handleJoiningFetchSendsErrorWhenSubscriptionDoesNotExist() async {
        let stream: MockTransportBiStream = .init()
        let context: SessionContext = .init(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let dispatcher: ControlMessageDispatcher = .init(sessionContext: context)
        let session: Session = .init(
            sessionContext: context,
            controlMessageReceiver: .init(controlStream: stream, dispatcher: dispatcher)
        )
        #expect(type(of: session) == Session.self)

        await dispatcher.handle(
            .fetch(
                .init(
                    requestID: 20,
                    subscriberPriority: 1,
                    groupOrder: .ascending,
                    mode: .joiningAbsolute(joiningRequestID: 99, startGroup: 7)
                )
            )
        )

        #expect(stream.sentBytes.count == 1)
        #expect(stream.sentBytes[0].first == UInt8(MessageType.fetchError.rawValue))
        let message: FetchErrorMessage
        do {
            message = try .decode(from: Data(stream.sentBytes[0].dropFirst(3)))
        } catch {
            Issue.record("Expected FETCH_ERROR payload: \(error)")
            return
        }
        #expect(message.requestID == 20)
        #expect(message.errorCode == 0x7)
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
