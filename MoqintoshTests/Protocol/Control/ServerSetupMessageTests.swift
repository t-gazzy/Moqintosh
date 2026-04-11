//
//  ServerSetupMessageTests.swift
//  MoqintoshTests
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct ServerSetupMessageTests {

    @Test func roundTrip() throws {
        let message: ServerSetupMessage = ServerSetupMessage(
            selectedVersion: 0xff00000E,
            parameters: [.maxRequestId(100), .maxAuthTokenCacheSize(16)]
        )
        let decoded: ServerSetupMessage = try .decode(from: Data(message.encode().dropFirst(3)))

        #expect(decoded.selectedVersion == 0xff00000E)
        #expect(decoded.parameters.count == 2)
    }

    @Test func typePrefix() {
        let message: ServerSetupMessage = ServerSetupMessage(selectedVersion: 0xff00000E, parameters: [])
        #expect(message.encode().first == 0x21)
    }
}
