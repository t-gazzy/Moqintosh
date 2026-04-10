//
//  PublishNamespaceErrorMessageTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Testing
@testable import Moqintosh

struct PublishNamespaceErrorMessageTests {

    @Test func roundTrip() throws {
        let message: PublishNamespaceErrorMessage = .init(requestID: 3, errorCode: 9, reasonPhrase: "nope")
        let decoded: PublishNamespaceErrorMessage = try .decode(from: Data(message.encode().dropFirst(3)))
        #expect(decoded.requestID == 3)
        #expect(decoded.errorCode == 9)
        #expect(decoded.reasonPhrase == "nope")
    }
}
