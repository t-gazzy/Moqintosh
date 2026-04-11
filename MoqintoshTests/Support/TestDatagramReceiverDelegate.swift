//
//  TestDatagramReceiverDelegate.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
@testable import Moqintosh

final class TestDatagramReceiverDelegate: DatagramReceiverDelegate {

    private(set) var receivedDatagrams: [ObjectDatagram]

    init() {
        self.receivedDatagrams = []
    }

    func datagramReceiver(_ receiver: DatagramReceiver, didReceive datagram: ObjectDatagram) {
        receivedDatagrams.append(datagram)
    }
}
