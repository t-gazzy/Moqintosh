//
//  ByteReaderTests.swift
//  MoqintoshTests
//
//  Created by takemasa kaji on 2026/04/10.
//

import Testing
import Foundation
@testable import Moqintosh

struct ByteReaderTests {

    // MARK: - readVarint

    @Test func readVarint1Byte() throws {
        let reader = ByteReader(data: Data([0x25])) // 0x25 = 37, top 2 bits = 00 → 1 byte
        let result = try reader.readVarint()
        #expect(result == 37)
    }

    @Test func readVarint2Bytes() throws {
        let reader = ByteReader(data: Data([0x52, 0x34])) // top 2 bits = 01 → 2 bytes, value = 0x1234
        let result = try reader.readVarint()
        #expect(result == 0x1234)
    }

    @Test func readVarint4Bytes() throws {
        let reader = ByteReader(data: Data([0x80, 0x00, 0x12, 0x34])) // top 2 bits = 10 → 4 bytes, value = 0x1234
        let result = try reader.readVarint()
        #expect(result == 0x1234)
    }

    @Test func readVarint8Bytes() throws {
        let reader = ByteReader(data: Data([0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x12, 0x34])) // top 2 bits = 11 → 8 bytes
        let result = try reader.readVarint()
        #expect(result == 0x1234)
    }

    @Test func readVarintInsufficientData() {
        let reader = ByteReader(data: Data())
        #expect(throws: ByteReaderError.self) {
            try reader.readVarint()
        }
    }

    // MARK: - readString

    @Test func readString() throws {
        let reader = ByteReader(data: Data([0x05]) + Data("hello".utf8))
        let result = try reader.readString()
        #expect(result == "hello")
    }

    @Test func readStringInvalidUTF8() {
        let reader = ByteReader(data: Data([0x02, 0xFF, 0xFE]))
        #expect(throws: ByteReaderError.self) {
            try reader.readString()
        }
    }

    @Test func readStringInsufficientData() {
        let reader = ByteReader(data: Data([0x05, 0x68, 0x65, 0x6C])) // length=5, only 3 bytes follow
        #expect(throws: ByteReaderError.self) {
            try reader.readString()
        }
    }

    // MARK: - Round-trip

    @Test func roundTripVarint() throws {
        let values: [UInt64] = [0, 63, 64, 16383, 16384, 1_073_741_823, 1_073_741_824, 4_611_686_018_427_387_903]
        for value in values {
            var written = Data()
            written.writeVarint(value)
            let reader = ByteReader(data: written)
            let read = try reader.readVarint()
            #expect(read == value)
        }
    }

    @Test func roundTripString() throws {
        let strings = ["", "hello", "Swift MOQT", "日本語"]
        for string in strings {
            var written = Data()
            written.writeString(string)
            let reader = ByteReader(data: written)
            let read = try reader.readString()
            #expect(read == string)
        }
    }

    @Test func readReadOnlyBytesKeepsSubviewRange() throws {
        let data: Data = Data([0x10, 0x20, 0x30, 0x40, 0x50])
        let reader: ByteReader = ByteReader(data: data)

        _ = try reader.readUInt8Value()
        let bytes: ReadOnlyBytes = try reader.readReadOnlyBytes(length: 3)
        let extracted: [UInt8] = bytes.withUnsafeBytes { rawBuffer in
            Array(rawBuffer.bindMemory(to: UInt8.self))
        }

        #expect(extracted == [0x20, 0x30, 0x40])
        #expect(bytes.count == 3)
    }
}
