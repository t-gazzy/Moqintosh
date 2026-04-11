//
//  SubscribeOKMessageTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Testing
@testable import Moqintosh

struct SubscribeOKMessageTests {

    @Test func roundTrip() throws {
        let message: SubscribeOKMessage = SubscribeOKMessage(
            requestID: 10,
            trackAlias: 11,
            expires: 12,
            groupOrder: .ascending,
            contentExist: .exists(Location(group: 13, object: 14)),
            deliveryTimeout: 15,
            maxCacheDuration: 16
        )
        let decoded: SubscribeOKMessage = try .decode(from: Data(message.encode().dropFirst(3)))

        #expect(decoded.requestID == 10)
        #expect(decoded.trackAlias == 11)
        #expect(decoded.expires == 12)
        #expect(decoded.groupOrder == .ascending)
        #expect(decoded.deliveryTimeout == 15)
        #expect(decoded.maxCacheDuration == 16)
    }
}
