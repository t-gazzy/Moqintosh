//
//  SubscriptionTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct SubscriptionTests {

    @Test func initializerStoresMetadata() {
        let publishedTrack: PublishedTrack = PublishedTrack(
            requestID: 2,
            resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("audio".utf8)),
            trackAlias: 3,
            groupOrder: .ascending,
            contentExist: .noContent,
            forward: true
        )
        let subscription: Subscription = Subscription(
            requestID: 4,
            publishedTrack: publishedTrack,
            expires: 5,
            subscriberPriority: 6,
            filter: .absoluteRange(start: Location(group: 7, object: 8), endGroup: 9)
        )

        #expect(subscription.requestID == 4)
        #expect(subscription.publishedTrack.trackAlias == 3)
        #expect(subscription.expires == 5)
        #expect(subscription.subscriberPriority == 6)
        if case .absoluteRange(let start, let endGroup) = subscription.filter {
            #expect(start.group == 7)
            #expect(endGroup == 9)
        } else {
            Issue.record("Expected absolute range filter")
        }
    }
}
