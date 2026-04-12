//
//  WriteExtensionTests.swift
//  MoqintoshTests
//
//  Created by takemasa kaji on 2026/04/10.
//

import Testing
import Foundation
@testable import Moqintosh

struct WriteExtensionTests {

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
}
