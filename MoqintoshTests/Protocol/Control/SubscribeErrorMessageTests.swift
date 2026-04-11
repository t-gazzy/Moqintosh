//
//  SubscribeErrorMessageTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Testing
@testable import Moqintosh

struct SubscribeErrorMessageTests {

    @Test func roundTrip() throws {
        let message: SubscribeErrorMessage = SubscribeErrorMessage(requestID: 12, errorCode: 4, reasonPhrase: "no-sub")
        let decoded: SubscribeErrorMessage = try .decode(from: Data(message.encode().dropFirst(3)))
        #expect(decoded.requestID == 12)
        #expect(decoded.errorCode == 4)
        #expect(decoded.reasonPhrase == "no-sub")
    }
}
