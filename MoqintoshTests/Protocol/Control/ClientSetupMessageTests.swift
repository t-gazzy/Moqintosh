//
//  ClientSetupMessageTests.swift
//  MoqintoshTests
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct ClientSetupMessageTests {

    @Test func roundTrip() throws {
        let message: ClientSetupMessage = .init(
            supportedVersions: [0xff00000E],
            parameters: [.path("/live"), .maxRequestId(100), .authority("example.com")]
        )
        let decoded: ClientSetupMessage = try .decode(from: Data(message.encode().dropFirst(3)))

        #expect(decoded.supportedVersions == [0xff00000E])
        #expect(decoded.parameters.count == 3)
    }

    @Test func typePrefix() {
        let message: ClientSetupMessage = .init(supportedVersions: [0xff00000E], parameters: [])
        #expect(message.encode().first == 0x20)
    }
}
