//
//  TestStreamReceiverDelegate.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

@testable import Moqintosh

final class TestStreamReceiverDelegate: StreamReceiverDelegate {

    private(set) var receivedObjects: [SubgroupObject]

    init() {
        self.receivedObjects = []
    }

    func streamReceiver(_ receiver: StreamReceiver, didReceive object: SubgroupObject) async {
        receivedObjects.append(object)
    }
}
