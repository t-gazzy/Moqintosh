//
//  TestStreamReceiverFactoryDelegate.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

@testable import Moqintosh

final class TestStreamReceiverFactoryDelegate: StreamReceiverFactoryDelegate {

    private(set) var receivers: [StreamReceiver]

    init() {
        self.receivers = []
    }

    func streamReceiverFactory(_ factory: StreamReceiverFactory, didCreate receiver: StreamReceiver) {
        receivers.append(receiver)
    }
}
