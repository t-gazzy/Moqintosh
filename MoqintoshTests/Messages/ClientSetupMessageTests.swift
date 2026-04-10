//
//  ClientSetupMessageTests.swift
//  MoqintoshTests
//
//  Created by takemasa kaji on 2026/04/10.
//

import Testing
@testable import Moqintosh

struct ClientSetupMessageTests {

    @Test func roundTrip() throws {
        let message = ClientSetupMessage(
            supportedVersions: [0xff00000E],
            parameters: [
                .path("/live"),
                .maxRequestId(100),
                .authority("example.com")
            ]
        )
        let encoded = message.encode()
        let decoded = try ClientSetupMessage.decode(from: encoded)

        #expect(decoded.supportedVersions == [0xff00000E])
        #expect(decoded.parameters.count == 3)

        guard case .path(let path) = decoded.parameters[0] else {
            Issue.record("Expected path at index 0")
            return
        }
        #expect(path == "/live")

        guard case .maxRequestId(let maxId) = decoded.parameters[1] else {
            Issue.record("Expected maxRequestId at index 1")
            return
        }
        #expect(maxId == 100)

        guard case .authority(let authority) = decoded.parameters[2] else {
            Issue.record("Expected authority at index 2")
            return
        }
        #expect(authority == "example.com")
    }

    @Test func typePrefix() {
        let message = ClientSetupMessage(supportedVersions: [0xff00000E], parameters: [])
        let encoded = message.encode()
        #expect(encoded.first == 0x20)
    }

    @Test func unexpectedType() {
        let message = ClientSetupMessage(supportedVersions: [0xff00000E], parameters: [])
        var encoded = message.encode()
        encoded[encoded.startIndex] = 0x21
        #expect(throws: ClientSetupMessageError.self) {
            try ClientSetupMessage.decode(from: encoded)
        }
    }
}
