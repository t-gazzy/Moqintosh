//
//  PublishNamespaceMessageTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct PublishNamespaceMessageTests {

    @Test func roundTrip() throws {
        let message: PublishNamespaceMessage = PublishNamespaceMessage(
            requestID: 2,
            trackNamespace: TrackNamespace(strings: ["live", "video"]),
            authorizationTokens: [AuthorizationToken(value: Data([0xAA]))]
        )
        let decoded: PublishNamespaceMessage = try .decode(from: Data(message.encode().dropFirst(3)))

        #expect(decoded.requestID == 2)
        #expect(decoded.trackNamespace.elements == message.trackNamespace.elements)
        #expect(decoded.authorizationTokens.count == 1)
        #expect(decoded.authorizationTokens[0].value == Data([0xAA]))
    }
}
