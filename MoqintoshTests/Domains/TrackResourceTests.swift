//
//  TrackResourceTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct TrackResourceTests {

    @Test func initializerStoresMetadata() {
        let token: AuthorizationToken = .init(value: Data([0x01, 0x02]))
        let resource: TrackResource = .init(
            trackNamespace: .init(strings: ["live", "sports"]),
            trackName: Data("video".utf8),
            authorizationToken: token
        )

        #expect(resource.trackNamespace.elements == [Data("live".utf8), Data("sports".utf8)])
        #expect(resource.trackName == Data("video".utf8))
        #expect(resource.authorizationToken?.value == Data([0x01, 0x02]))
    }
}
