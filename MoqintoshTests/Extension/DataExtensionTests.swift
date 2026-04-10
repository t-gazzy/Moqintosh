//
//  DataExtensionTests.swift
//  MoqintoshTests
//
//  Created by takemasa kaji on 2026/04/10.
//

import Testing
@testable import Moqintosh

struct DataExtensionTests {

    // MARK: - readVarint

    @Test func readVarint1Byte() throws {
        var data = Data([0x25]) // 0x25 = 37, top 2 bits = 00 → 1 byte
        var offset: Int = 0
        let result = try data.readVarint(at: &offset)
        #expect(result == 37)
        #expect(offset == 1)
    }

    @Test func readVarint2Bytes() throws {
        // 0x4000 ^ 0x1234 = 0x5234, encoded as big-endian 2 bytes
        var data = Data([0x52, 0x34]) // top 2 bits = 01 → 2 bytes, value = 0x1234
        var offset: Int = 0
        let result = try data.readVarint(at: &offset)
        #expect(result == 0x1234)
        #expect(offset == 2)
    }

    @Test func readVarint4Bytes() throws {
        // 0x8000_0000 ^ 0x0000_1234 = 0x8000_1234
        var data = Data([0x80, 0x00, 0x12, 0x34]) // top 2 bits = 10 → 4 bytes, value = 0x1234
        var offset: Int = 0
        let result = try data.readVarint(at: &offset)
        #expect(result == 0x1234)
        #expect(offset == 4)
    }

    @Test func readVarint8Bytes() throws {
        // 0xC000_0000_0000_0000 ^ 0x0000_0000_0000_1234 = 0xC000_0000_0000_1234
        var data = Data([0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x12, 0x34]) // top 2 bits = 11 → 8 bytes
        var offset: Int = 0
        let result = try data.readVarint(at: &offset)
        #expect(result == 0x1234)
        #expect(offset == 8)
    }

    @Test func readVarintInsufficientData() {
        var data = Data()
        var offset: Int = 0
        #expect(throws: DataReadError.self) {
            try data.readVarint(at: &offset)
        }
    }

    // MARK: - readString

    @Test func readString() throws {
        // varint length = 5 (1 byte, 0x05), followed by "hello"
        var data = Data([0x05]) + Data("hello".utf8)
        var offset: Int = 0
        let result = try data.readString(at: &offset)
        #expect(result == "hello")
        #expect(offset == 6)
    }

    @Test func readStringInvalidUTF8() {
        // varint length = 2, followed by invalid UTF-8 bytes
        var data = Data([0x02, 0xFF, 0xFE])
        var offset: Int = 0
        #expect(throws: DataReadError.self) {
            try data.readString(at: &offset)
        }
    }

    @Test func readStringInsufficientData() {
        // varint length = 5, but only 3 bytes follow
        var data = Data([0x05, 0x68, 0x65, 0x6C])
        var offset: Int = 0
        #expect(throws: DataReadError.self) {
            try data.readString(at: &offset)
        }
    }

    // MARK: - writeVarint

    @Test func writeVarint1Byte() {
        var data = Data()
        data.writeVarint(37)
        #expect(data == Data([0x25]))
    }

    @Test func writeVarint2Bytes() {
        var data = Data()
        data.writeVarint(0x1234)
        #expect(data == Data([0x52, 0x34]))
    }

    @Test func writeVarint4Bytes() {
        var data = Data()
        data.writeVarint(0x0000_4000) // 16384, minimum value for 4-byte encoding
        #expect(data == Data([0x80, 0x00, 0x40, 0x00]))
    }

    @Test func writeVarint8Bytes() {
        var data = Data()
        data.writeVarint(0x0000_0000_4000_0000) // minimum value for 8-byte encoding
        #expect(data == Data([0xC0, 0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x00]))
    }

    // MARK: - writeString

    @Test func writeString() {
        var data = Data()
        data.writeString("hello")
        #expect(data == Data([0x05]) + Data("hello".utf8))
    }

    @Test func writeStringEmpty() {
        var data = Data()
        data.writeString("")
        #expect(data == Data([0x00]))
    }

    // MARK: - Round-trip

    @Test func roundTripVarint() throws {
        let values: [UInt64] = [0, 63, 64, 16383, 16384, 1_073_741_823, 1_073_741_824, 4_611_686_018_427_387_903]
        for value in values {
            var written = Data()
            written.writeVarint(value)
            var offset: Int = 0
            let read = try written.readVarint(at: &offset)
            #expect(read == Int(value))
        }
    }

    @Test func roundTripString() throws {
        let strings = ["", "hello", "Swift MOQT", "日本語"]
        for string in strings {
            var written = Data()
            written.writeString(string)
            var offset: Int = 0
            let read = try written.readString(at: &offset)
            #expect(read == string)
        }
    }
}
