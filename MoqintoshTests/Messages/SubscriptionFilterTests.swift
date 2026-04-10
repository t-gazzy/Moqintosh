//
//  SubscriptionFilterTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Testing
@testable import Moqintosh

struct SubscriptionFilterTests {

    @Test func roundTrip() throws {
        let filters: [SubscriptionFilter] = [
            .nextGroupStart,
            .largestObject,
            .absoluteStart(.init(group: 1, object: 2)),
            .absoluteRange(start: .init(group: 3, object: 4), endGroup: 5)
        ]

        for filter in filters {
            let decoded: SubscriptionFilter = try .decode(from: .init(data: filter.encode()))

            switch (filter, decoded) {
            case (.nextGroupStart, .nextGroupStart), (.largestObject, .largestObject):
                break
            case (.absoluteStart(let lhs), .absoluteStart(let rhs)):
                #expect(lhs.group == rhs.group)
                #expect(lhs.object == rhs.object)
            case (.absoluteRange(let lhsStart, let lhsEnd), .absoluteRange(let rhsStart, let rhsEnd)):
                #expect(lhsStart.group == rhsStart.group)
                #expect(lhsStart.object == rhsStart.object)
                #expect(lhsEnd == rhsEnd)
            default:
                Issue.record("Decoded filter did not match original")
            }
        }
    }
}
