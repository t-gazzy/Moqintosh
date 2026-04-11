//
//  KeyValuePairTests.swift
//  MoqintoshTests
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct KeyValuePairTests {

    @Test func encodeVarint() {
        let pair: KeyValuePair = KeyValuePair(type: 0x02, value: .varint(10))
        #expect(pair.encode() == Data([0x02, 0x0A]))
    }

    @Test func encodeBytes() {
        let pair: KeyValuePair = KeyValuePair(type: 0x01, value: .bytes(Data("hi".utf8)))
        #expect(pair.encode() == Data([0x01, 0x02, 0x68, 0x69]))
    }

    @Test func roundTripVarint() throws {
        let pair: KeyValuePair = KeyValuePair(type: 0x02, value: .varint(1024))
        let decoded: KeyValuePair = try .decode(from: ByteReader(data: pair.encode()))
        #expect(decoded.type == 0x02)
        guard case .varint(let value) = decoded.value else {
            Issue.record("Expected varint")
            return
        }
        #expect(value == 1024)
    }

    @Test func roundTripBytes() throws {
        let pair: KeyValuePair = KeyValuePair(type: 0x05, value: .bytes(Data("example.com".utf8)))
        let decoded: KeyValuePair = try .decode(from: ByteReader(data: pair.encode()))
        #expect(decoded.type == 0x05)
        guard case .bytes(let value) = decoded.value else {
            Issue.record("Expected bytes")
            return
        }
        #expect(value == Data("example.com".utf8))
    }
}
