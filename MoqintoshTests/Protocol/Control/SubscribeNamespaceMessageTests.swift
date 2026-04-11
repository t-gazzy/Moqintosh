//
//  SubscribeNamespaceMessageTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct SubscribeNamespaceMessageTests {

    @Test func roundTrip() throws {
        let message: SubscribeNamespaceMessage = SubscribeNamespaceMessage(
            requestID: 4,
            namespacePrefix: TrackNamespace(strings: ["live"]),
            authorizationTokens: [AuthorizationToken(value: Data([0x01, 0x02]))]
        )
        let decoded: SubscribeNamespaceMessage = try .decode(from: Data(message.encode().dropFirst(3)))

        #expect(decoded.requestID == 4)
        #expect(decoded.namespacePrefix.elements == message.namespacePrefix.elements)
        #expect(decoded.authorizationTokens.count == 1)
        #expect(decoded.authorizationTokens[0].value == Data([0x01, 0x02]))
    }
}
