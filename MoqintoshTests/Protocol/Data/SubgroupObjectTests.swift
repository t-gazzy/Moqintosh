//
//  SubgroupObjectTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct SubgroupObjectTests {

    @Test func roundTripPayload() throws {
        let header: SubgroupHeader = SubgroupHeader(
            trackAlias: 1,
            groupID: 2,
            subgroupID: .explicit(3),
            publisherPriority: 4,
            usesExtensions: true
        )
        let object: SubgroupObject = header.makeObject(
            previousObjectID: 9,
            objectID: 10,
            extensions: [KeyValuePair(type: 0x03, value: .bytes(ReadOnlyBytes(Data([0xAA]))))],
            content: .payload(ReadOnlyBytes(Data("abcd".utf8)))
        )

        let decoded: SubgroupObject = try .decode(object.encode(), header: header, previousObjectID: 9)

        #expect(decoded.objectID == 10)
        #expect(decoded.extensions.count == 1)
        if case .payload(let payload) = decoded.content {
            #expect(payload.equals(Data("abcd".utf8)))
        } else {
            Issue.record("Expected payload content")
        }
    }

    @Test func firstObjectUsesAbsoluteObjectID() throws {
        let header: SubgroupHeader = SubgroupHeader(
            trackAlias: 1,
            groupID: 2,
            subgroupID: .firstObject,
            publisherPriority: 4
        )
        let object: SubgroupObject = header.makeObject(objectID: 7, content: .status(9))

        #expect(object.encode() == Data([0x07, 0x00, 0x09]))
        #expect(header.resolvedSubgroupID(firstObjectID: 7) == 7)
    }
}
