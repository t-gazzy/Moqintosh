//
//  PublishNamespaceOKMessageTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Testing
@testable import Moqintosh

struct PublishNamespaceOKMessageTests {

    @Test func roundTrip() throws {
        let message: PublishNamespaceOKMessage = PublishNamespaceOKMessage(requestID: 3)
        let decoded: PublishNamespaceOKMessage = try .decode(from: Data(message.encode().dropFirst(3)))
        #expect(decoded.requestID == 3)
    }
}
