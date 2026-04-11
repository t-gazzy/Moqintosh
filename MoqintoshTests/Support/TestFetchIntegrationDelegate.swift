//
//  TestFetchIntegrationDelegate.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/12.
//

@testable import Moqintosh

final class TestFetchIntegrationDelegate: FetchReceiverFactoryDelegate, FetchReceiverDelegate {

    private(set) var receivers: [FetchReceiver]
    private(set) var receivedObjects: [SubgroupObject]
    private(set) var closedReceiverCount: Int

    init() {
        self.receivers = []
        self.receivedObjects = []
        self.closedReceiverCount = 0
    }

    func fetchReceiverFactory(_ factory: FetchReceiverFactory, didCreate receiver: FetchReceiver) {
        receiver.delegate = self
        receivers.append(receiver)
    }

    func fetchReceiver(_ receiver: FetchReceiver, didReceive object: SubgroupObject) {
        receivedObjects.append(object)
    }

    func fetchReceiverDidClose(_ receiver: FetchReceiver) {
        closedReceiverCount += 1
    }
}
