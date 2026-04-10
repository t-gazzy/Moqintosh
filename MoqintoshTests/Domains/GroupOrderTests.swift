//
//  GroupOrderTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Testing
@testable import Moqintosh

struct GroupOrderTests {

    @Test func rawValuesMatchDraft() {
        #expect(GroupOrder.publisherDefault.rawValue == 0x00)
        #expect(GroupOrder.ascending.rawValue == 0x01)
        #expect(GroupOrder.descending.rawValue == 0x02)
    }
}
