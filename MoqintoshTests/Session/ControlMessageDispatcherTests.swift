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
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let dispatcher: ControlMessageDispatcher = ControlMessageDispatcher(sessionContext: context)
        let session: Session = Session(
            sessionContext: context,
            controlMessageReceiver: ControlMessageReceiver(controlStream: stream)
        )
        let delegate: TestSessionDelegate = TestSessionDelegate()
        session.delegate = delegate

        await dispatcher.handle(
            .publishNamespace(
                PublishNamespaceMessage(
                    requestID: 2,
                    trackNamespace: TrackNamespace(strings: ["live"]),
                    authorizationTokens: [AuthorizationToken(value: Data([0x01]))]
                )
            )
        )

        #expect(delegate.receivedPublishNamespace?.elements == [Data("live".utf8)])
        #expect(delegate.receivedPublishNamespaceAuthorizationToken?.value == Data([0x01]))
        #expect(stream.sentBytes.count == 1)
        #expect(stream.sentBytes[0].first == UInt8(MessageType.publishNamespaceOK.rawValue))
    }

    @Test func handleSubscribeSendsErrorWhenDelegateRejects() async {
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let dispatcher: ControlMessageDispatcher = ControlMessageDispatcher(sessionContext: context)
        let session: Session = Session(
            sessionContext: context,
            controlMessageReceiver: ControlMessageReceiver(controlStream: stream)
        )
        let delegate: TestSessionDelegate = TestSessionDelegate()
        delegate.subscribeError = SubscribeRequestError(
            code: .trackDoesNotExist,
            reason: "Track does not exist"
        )
        session.delegate = delegate

        await dispatcher.handle(
            .subscribe(
                SubscribeMessage(
                    requestID: 4,
                    resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("video".utf8)),
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
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let dispatcher: ControlMessageDispatcher = ControlMessageDispatcher(sessionContext: context)
        let session: Session = Session(
            sessionContext: context,
            controlMessageReceiver: ControlMessageReceiver(controlStream: stream)
        )
        let delegate: TestSessionDelegate = TestSessionDelegate()
        delegate.trackStatusResult = TrackStatus(
            expires: 5,
            groupOrder: .ascending,
            contentExist: .noContent,
            deliveryTimeout: nil,
            maxCacheDuration: nil
        )
        session.delegate = delegate

        await dispatcher.handle(
            .trackStatus(
                TrackStatusMessage(
                    requestID: 8,
                    resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("video".utf8)),
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
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let dispatcher: ControlMessageDispatcher = ControlMessageDispatcher(sessionContext: context)
        let session: Session = Session(
            sessionContext: context,
            controlMessageReceiver: ControlMessageReceiver(controlStream: stream)
        )
        let delegate: TestSessionDelegate = TestSessionDelegate()
        delegate.fetchResponse = FetchResponse(
            groupOrder: .ascending,
            endOfTrack: true,
            endLocation: Location(group: 7, object: 8),
            maxCacheDuration: 9
        )
        session.delegate = delegate

        await dispatcher.handle(
            .fetch(
                FetchMessage(
                    requestID: 10,
                    subscriberPriority: 1,
                    groupOrder: .ascending,
                    mode: .standalone(
                        resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("video".utf8)),
                        start: Location(group: 1, object: 2),
                        end: Location(group: 3, object: 4)
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
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let dispatcher: ControlMessageDispatcher = ControlMessageDispatcher(sessionContext: context)
        let session: Session = Session(
            sessionContext: context,
            controlMessageReceiver: ControlMessageReceiver(controlStream: stream)
        )
        let delegate: TestSessionDelegate = TestSessionDelegate()
        session.delegate = delegate

        await dispatcher.handle(.fetchCancel(FetchCancelMessage(requestID: 12)))

        #expect(delegate.receivedFetchCancelRequestID == 12)
    }

    @Test func handleJoiningRelativeFetchSendsOKWhenSubscriptionExists() async {
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let dispatcher: ControlMessageDispatcher = ControlMessageDispatcher(sessionContext: context)
        let session: Session = Session(
            sessionContext: context,
            controlMessageReceiver: ControlMessageReceiver(controlStream: stream)
        )
        let delegate: TestSessionDelegate = TestSessionDelegate()
        delegate.fetchResponse = FetchResponse(
            groupOrder: .ascending,
            endOfTrack: false,
            endLocation: Location(group: 13, object: 14),
            maxCacheDuration: nil
        )
        session.delegate = delegate
        context.registerInboundSubscriptionResource(
            requestID: 4,
            resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("video".utf8))
        )

        await dispatcher.handle(
            .fetch(
                FetchMessage(
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
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let dispatcher: ControlMessageDispatcher = ControlMessageDispatcher(sessionContext: context)
        let session: Session = Session(
            sessionContext: context,
            controlMessageReceiver: ControlMessageReceiver(controlStream: stream)
        )
        #expect(type(of: session) == Session.self)

        await dispatcher.handle(
            .fetch(
                FetchMessage(
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
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let dispatcher: ControlMessageDispatcher = ControlMessageDispatcher(sessionContext: context)
        let session: Session = Session(
            sessionContext: context,
            controlMessageReceiver: ControlMessageReceiver(controlStream: stream)
        )
        let delegate: TestSessionDelegate = TestSessionDelegate()
        session.delegate = delegate

        await dispatcher.handle(.goaway(GoAwayMessage(newSessionURI: "https://example.com")))

        #expect(delegate.receivedGoAwayURI == "https://example.com")
    }
}
