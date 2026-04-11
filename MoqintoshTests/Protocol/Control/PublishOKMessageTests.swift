//
//  PublishOKMessageTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Testing
@testable import Moqintosh

struct PublishOKMessageTests {

    @Test func roundTrip() throws {
        let message: PublishOKMessage = .init(
            requestID: 7,
            forward: true,
            subscriberPriority: 1,
            groupOrder: .descending,
            filter: .absoluteRange(start: .init(group: 1, object: 2), endGroup: 3),
            deliveryTimeout: 30
        )
        let decoded: PublishOKMessage = try .decode(from: Data(message.encode().dropFirst(3)))

        #expect(decoded.requestID == 7)
        #expect(decoded.forward)
        #expect(decoded.subscriberPriority == 1)
        #expect(decoded.groupOrder == .descending)
        #expect(decoded.deliveryTimeout == 30)
    }
}
