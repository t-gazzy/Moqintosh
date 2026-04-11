//
//  ObjectDatagramTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct ObjectDatagramTests {

    @Test func roundTripPayloadWithExtensions() throws {
        let message: ObjectDatagram = .init(
            trackAlias: 2,
            groupID: 3,
            objectID: .explicit(4),
            publisherPriority: 5,
            extensions: [.init(type: 0x03, value: .bytes(Data([0xAA])))],
            endOfGroup: true,
            content: .payload(Data("abc".utf8))
        )

        let decoded: ObjectDatagram = try .decode(message.encode())

        #expect(decoded.trackAlias == 2)
        #expect(decoded.groupID == 3)
        #expect(decoded.publisherPriority == 5)
        #expect(decoded.endOfGroup == true)
        #expect(decoded.extensions.count == 1)
        if case .explicit(let objectID) = decoded.objectID {
            #expect(objectID == 4)
        } else {
            Issue.record("Expected an explicit object ID")
        }
        if case .payload(let payload) = decoded.content {
            #expect(payload == Data("abc".utf8))
        } else {
            Issue.record("Expected payload content")
        }
    }

    @Test func roundTripStatus() throws {
        let message: ObjectDatagram = .init(
            trackAlias: 2,
            groupID: 3,
            objectID: .explicit(4),
            publisherPriority: 5,
            content: .status(6)
        )

        let decoded: ObjectDatagram = try .decode(message.encode())

        if case .status(let status) = decoded.content {
            #expect(status == 6)
        } else {
            Issue.record("Expected status content")
        }
    }
}
