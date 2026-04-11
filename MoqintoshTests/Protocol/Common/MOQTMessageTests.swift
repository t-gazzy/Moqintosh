//
//  MOQTMessageTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct MOQTMessageTests {

    @Test func unknownPayload() {
        let message: MOQTMessage = .unknown(type: 0x99, payload: Data([0x01, 0x02]))

        guard case .unknown(let type, let payload) = message else {
            Issue.record("Expected unknown message")
            return
        }

        #expect(type == 0x99)
        #expect(payload == Data([0x01, 0x02]))
    }
}
