//
//  SubscribeNamespaceOKMessageTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Testing
@testable import Moqintosh

struct SubscribeNamespaceOKMessageTests {

    @Test func roundTrip() throws {
        let message: SubscribeNamespaceOKMessage = .init(requestID: 5)
        let decoded: SubscribeNamespaceOKMessage = try .decode(from: Data(message.encode().dropFirst(3)))
        #expect(decoded.requestID == 5)
    }
}
