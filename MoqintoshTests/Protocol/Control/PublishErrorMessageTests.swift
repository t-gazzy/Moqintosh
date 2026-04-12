//
//  PublishErrorMessageTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Testing
import Foundation
@testable import Moqintosh

struct PublishErrorMessageTests {

    @Test func roundTrip() throws {
        let message: PublishErrorMessage = PublishErrorMessage(requestID: 8, errorCode: 2, reasonPhrase: "rejected")
        let decoded: PublishErrorMessage = try .decode(from: Data(message.encode().dropFirst(3)))
        #expect(decoded.requestID == 8)
        #expect(decoded.errorCode == 2)
        #expect(decoded.reasonPhrase == "rejected")
    }
}
