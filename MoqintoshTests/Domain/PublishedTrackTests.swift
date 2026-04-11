//
//  PublishedTrackTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct PublishedTrackTests {

    @Test func initializerStoresMetadata() {
        let resource: TrackResource = TrackResource(
            trackNamespace: TrackNamespace(strings: ["live"]),
            trackName: Data("video".utf8)
        )
        let track: PublishedTrack = PublishedTrack(
            requestID: 2,
            resource: resource,
            trackAlias: 3,
            groupOrder: .descending,
            contentExist: .exists(Location(group: 4, object: 5)),
            forward: false
        )

        #expect(track.requestID == 2)
        #expect(track.resource.trackNamespace.elements == [Data("live".utf8)])
        #expect(track.trackAlias == 3)
        #expect(track.groupOrder == .descending)
        #expect(track.forward == false)
        if case .exists(let location) = track.contentExist {
            #expect(location.group == 4)
            #expect(location.object == 5)
        } else {
            Issue.record("Expected content to exist")
        }
    }
}
