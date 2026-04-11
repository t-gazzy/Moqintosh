//
//  TestFetchReceiverDelegate.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/12.
//

@testable import Moqintosh

final class TestFetchReceiverDelegate: FetchReceiverDelegate {

    private(set) var receivedObjects: [SubgroupObject]
    private(set) var closedReceiverCount: Int

    init() {
        self.receivedObjects = []
        self.closedReceiverCount = 0
    }

    func fetchReceiver(_ receiver: FetchReceiver, didReceive object: SubgroupObject) {
        receivedObjects.append(object)
    }

    func fetchReceiverDidClose(_ receiver: FetchReceiver) {
        closedReceiverCount += 1
    }
}
