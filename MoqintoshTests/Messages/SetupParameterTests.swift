//
//  SetupParameterTests.swift
//  MoqintoshTests
//
//  Created by takemasa kaji on 2026/04/10.
//

import Testing
@testable import Moqintosh

struct SetupParameterTests {

    @Test func encodePath() throws {
        let encoded = SetupParameter.path("/live").encode()
        var offset: Int = 0
        let decoded = try SetupParameter.decode(from: encoded, at: &offset)
        guard case .path(let s) = decoded else {
            Issue.record("Expected path")
            return
        }
        #expect(s == "/live")
    }

    @Test func encodeMaxRequestId() throws {
        let encoded = SetupParameter.maxRequestId(128).encode()
        var offset: Int = 0
        let decoded = try SetupParameter.decode(from: encoded, at: &offset)
        guard case .maxRequestId(let v) = decoded else {
            Issue.record("Expected maxRequestId")
            return
        }
        #expect(v == 128)
    }

    @Test func encodeAuthority() throws {
        let encoded = SetupParameter.authority("example.com").encode()
        var offset: Int = 0
        let decoded = try SetupParameter.decode(from: encoded, at: &offset)
        guard case .authority(let s) = decoded else {
            Issue.record("Expected authority")
            return
        }
        #expect(s == "example.com")
    }

    @Test func encodeMoqtImplementation() throws {
        let encoded = SetupParameter.moqtImplementation("Moqintosh").encode()
        var offset: Int = 0
        let decoded = try SetupParameter.decode(from: encoded, at: &offset)
        guard case .moqtImplementation(let s) = decoded else {
            Issue.record("Expected moqtImplementation")
            return
        }
        #expect(s == "Moqintosh")
    }
}
