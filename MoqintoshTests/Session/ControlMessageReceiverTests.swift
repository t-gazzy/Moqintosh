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
        let incoming: PublishNamespaceMessage = .init(requestID: 2, trackNamespace: .init(strings: ["live"]))
        let stream: MockTransportBiStream = .init(receiveQueue: [incoming.encode()])
        let context: SessionContext = .init(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let dispatcher: ControlMessageDispatcher = .init(sessionContext: context)
        let receiver: ControlMessageReceiver = .init(controlStream: stream, dispatcher: dispatcher)
        let session: Session = .init(sessionContext: context, controlMessageReceiver: receiver)
        let delegate: TestSessionDelegate = .init()
        delegate.publishNamespaceResult = true
        session.delegate = delegate

        while stream.sentBytes.isEmpty {
            await Task.yield()
        }

        #expect(delegate.receivedPublishNamespace?.elements == [Data("live".utf8)])
        #expect(stream.sentBytes[0].first == UInt8(MessageType.publishNamespaceOK.rawValue))
    }
}
