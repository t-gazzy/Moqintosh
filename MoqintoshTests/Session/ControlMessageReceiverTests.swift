//
//  ControlMessageReceiverTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct ControlMessageReceiverTests {

    @Test func startReadsMessageAndDispatchesIt() async {
        let incoming: PublishNamespaceMessage = PublishNamespaceMessage(requestID: 2, trackNamespace: TrackNamespace(strings: ["live"]))
        let stream: MockTransportBiStream = MockTransportBiStream(receiveQueue: [incoming.encode()])
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let dispatcher: ControlMessageDispatcher = ControlMessageDispatcher(sessionContext: context)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: stream, dispatcher: dispatcher)
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)
        let delegate: TestSessionDelegate = TestSessionDelegate()
        delegate.publishNamespaceResult = true
        session.delegate = delegate

        while stream.sentBytes.isEmpty {
            await Task.yield()
        }

        #expect(delegate.receivedPublishNamespace?.elements == [Data("live".utf8)])
        #expect(stream.sentBytes[0].first == UInt8(MessageType.publishNamespaceOK.rawValue))
    }
}
