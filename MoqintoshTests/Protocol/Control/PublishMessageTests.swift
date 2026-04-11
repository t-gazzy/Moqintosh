//
//  PublishMessageTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct PublishMessageTests {

    @Test func roundTrip() throws {
        let track: PublishedTrack = .init(
            requestID: 6,
            resource: .init(
                trackNamespace: .init(strings: ["live"]),
                trackName: Data("video".utf8),
                authorizationToken: .init(value: Data([0x10]))
            ),
            trackAlias: 1,
            groupOrder: .ascending,
            contentExist: .exists(.init(group: 7, object: 8)),
            forward: true
        )
        let message: PublishMessage = .init(
            requestID: 6,
            publishedTrack: track,
            deliveryTimeout: 9,
            maxCacheDuration: 10
        )
        let decoded: PublishMessage = try .decode(from: Data(message.encode().dropFirst(3)))

        #expect(decoded.requestID == 6)
        #expect(decoded.publishedTrack.trackAlias == 1)
        #expect(decoded.deliveryTimeout == 9)
        #expect(decoded.maxCacheDuration == 10)

        guard case .exists(let location) = decoded.publishedTrack.contentExist else {
            Issue.record("Expected existing content")
            return
        }
        #expect(location.group == 7)
        #expect(location.object == 8)
    }
}
