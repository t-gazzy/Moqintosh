//
//  MessageTypeTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Testing
@testable import Moqintosh

struct MessageTypeTests {

    @Test func rawValues() {
        #expect(MessageType.clientSetup.rawValue == 0x20)
        #expect(MessageType.publish.rawValue == 0x1D)
        #expect(MessageType.publishNamespace.rawValue == 0x06)
        #expect(MessageType.subscribe.rawValue == 0x03)
        #expect(MessageType.subscribeNamespace.rawValue == 0x11)
    }
}
