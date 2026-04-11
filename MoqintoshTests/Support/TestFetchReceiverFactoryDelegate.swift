//
//  TestFetchReceiverFactoryDelegate.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/12.
//

@testable import Moqintosh

final class TestFetchReceiverFactoryDelegate: FetchReceiverFactoryDelegate {

    private(set) var receivers: [FetchReceiver]

    init() {
        self.receivers = []
    }

    func fetchReceiverFactory(_ factory: FetchReceiverFactory, didCreate receiver: FetchReceiver) {
        receivers.append(receiver)
    }
}
