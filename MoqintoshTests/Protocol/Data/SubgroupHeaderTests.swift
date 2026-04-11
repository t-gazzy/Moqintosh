//
//  SubgroupHeaderTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Testing
@testable import Moqintosh

struct SubgroupHeaderTests {

    @Test func roundTripExplicitSubgroupID() throws {
        let header: SubgroupHeader = SubgroupHeader(
            trackAlias: 2,
            groupID: 3,
            subgroupID: .explicit(4),
            publisherPriority: 5,
            usesExtensions: true,
            containsEndOfGroup: true
        )

        let decoded: SubgroupHeader = try .decode(header.encode())

        #expect(decoded.trackAlias == 2)
        #expect(decoded.groupID == 3)
        #expect(decoded.publisherPriority == 5)
        #expect(decoded.usesExtensions == true)
        #expect(decoded.containsEndOfGroup == true)
        if case .explicit(let subgroupID) = decoded.subgroupID {
            #expect(subgroupID == 4)
        } else {
            Issue.record("Expected an explicit subgroup ID")
        }
    }
}
