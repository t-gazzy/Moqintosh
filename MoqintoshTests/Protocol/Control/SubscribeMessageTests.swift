//
//  SubscribeMessageTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct SubscribeMessageTests {

    @Test func roundTrip() throws {
        let message: SubscribeMessage = SubscribeMessage(
            requestID: 9,
            resource: TrackResource(
                trackNamespace: TrackNamespace(strings: ["live"]),
                trackName: Data("audio".utf8),
                authorizationToken: AuthorizationToken(value: Data([0x20]))
            ),
            subscriberPriority: 2,
            groupOrder: .publisherDefault,
            forward: false,
            filter: .absoluteStart(Location(group: 3, object: 4)),
            deliveryTimeout: 50
        )
        let decoded: SubscribeMessage = try .decode(from: Data(message.encode().dropFirst(3)))

        #expect(decoded.requestID == 9)
        #expect(decoded.subscriberPriority == 2)
        #expect(decoded.groupOrder == .publisherDefault)
        #expect(!decoded.forward)
        #expect(decoded.deliveryTimeout == 50)
        #expect(decoded.resource.authorizationToken?.value == Data([0x20]))
    }
}
