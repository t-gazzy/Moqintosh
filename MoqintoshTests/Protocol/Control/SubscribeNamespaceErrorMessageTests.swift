//
//  SubscribeNamespaceErrorMessageTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Testing
import Foundation

@testable import Moqintosh

struct SubscribeNamespaceErrorMessageTests {

    @Test func roundTrip() throws {
        let message: SubscribeNamespaceErrorMessage = SubscribeNamespaceErrorMessage(requestID: 5, errorCode: 11, reasonPhrase: "denied")
        let decoded: SubscribeNamespaceErrorMessage = try .decode(from: Data(message.encode().dropFirst(3)))
        #expect(decoded.requestID == 5)
        #expect(decoded.errorCode == 11)
        #expect(decoded.reasonPhrase == "denied")
    }
}
