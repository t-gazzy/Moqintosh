//
//  ServerSetupMessageTests.swift
//  MoqintoshTests
//
//  Created by takemasa kaji on 2026/04/10.
//

import Testing
@testable import Moqintosh

struct ServerSetupMessageTests {

    @Test func roundTrip() throws {
        let message = ServerSetupMessage(
            selectedVersion: 0xff00000E,
            parameters: [
                .maxRequestId(100)
            ]
        )
        let encoded = message.encode()
        let decoded = try ServerSetupMessage.decode(from: encoded)

        #expect(decoded.selectedVersion == 0xff00000E)
        #expect(decoded.parameters.count == 1)

        guard case .maxRequestId(let maxId) = decoded.parameters[0] else {
            Issue.record("Expected maxRequestId at index 0")
            return
        }
        #expect(maxId == 100)
    }

    @Test func typePrefix() {
        let message = ServerSetupMessage(selectedVersion: 0xff00000E, parameters: [])
        let encoded = message.encode()
        // First byte should be type 0x21
        #expect(encoded.first == 0x21)
    }

    @Test func unexpectedType() {
        let message = ServerSetupMessage(selectedVersion: 0xff00000E, parameters: [])
        var encoded = message.encode()
        encoded[encoded.startIndex] = 0x20
        #expect(throws: ServerSetupMessageError.self) {
            try ServerSetupMessage.decode(from: encoded)
        }
    }

    @Test func noParameters() throws {
        let message = ServerSetupMessage(selectedVersion: 0x00000001, parameters: [])
        let encoded = message.encode()
        let decoded = try ServerSetupMessage.decode(from: encoded)
        #expect(decoded.selectedVersion == 0x00000001)
        #expect(decoded.parameters.isEmpty)
    }
}
