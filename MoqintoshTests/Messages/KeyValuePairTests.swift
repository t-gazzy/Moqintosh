//
//  KeyValuePairTests.swift
//  MoqintoshTests
//
//  Created by takemasa kaji on 2026/04/10.
//

import Testing
@testable import Moqintosh

struct KeyValuePairTests {

    @Test func encodeVarint() {
        let pair = KeyValuePair(type: 0x02, value: .varint(10))
        let data = pair.encode()
        // type = 0x02 (1 byte), value = 10 (1 byte, < 0x40 so single-byte varint)
        #expect(data == Data([0x02, 0x0A]))
    }

    @Test func encodeBytes() {
        let pair = KeyValuePair(type: 0x01, value: .bytes(Data("hi".utf8)))
        let data = pair.encode()
        // type = 0x01 (1 byte), length = 2 (1 byte), "hi" = 0x68, 0x69
        #expect(data == Data([0x01, 0x02, 0x68, 0x69]))
    }

    @Test func roundTripVarint() throws {
        let pair = KeyValuePair(type: 0x02, value: .varint(1024))
        let encoded = pair.encode()
        var offset: Int = 0
        let decoded = try KeyValuePair.decode(from: encoded, at: &offset)
        #expect(decoded.type == 0x02)
        guard case .varint(let v) = decoded.value else {
            Issue.record("Expected varint")
            return
        }
        #expect(v == 1024)
    }

    @Test func roundTripBytes() throws {
        let pair = KeyValuePair(type: 0x05, value: .bytes(Data("example.com".utf8)))
        let encoded = pair.encode()
        var offset: Int = 0
        let decoded = try KeyValuePair.decode(from: encoded, at: &offset)
        #expect(decoded.type == 0x05)
        guard case .bytes(let bytes) = decoded.value else {
            Issue.record("Expected bytes")
            return
        }
        #expect(bytes == Data("example.com".utf8))
    }
}
