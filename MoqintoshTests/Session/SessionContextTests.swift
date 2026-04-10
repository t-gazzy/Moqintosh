//
//  SessionContextTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct SessionContextTests {

    @Test func issueRequestIDIncrementsByTwo() {
        let context: SessionContext = .init(connection: MockTransportConnection(), controlStream: MockTransportBiStream())
        #expect(context.issueRequestID() == 0)
        #expect(context.issueRequestID() == 2)
        #expect(context.issueRequestID() == 4)
    }

    @Test func issueTrackAliasIncrementsByOne() {
        let context: SessionContext = .init(connection: MockTransportConnection(), controlStream: MockTransportBiStream())
        #expect(context.issueTrackAlias() == 0)
        #expect(context.issueTrackAlias() == 1)
        #expect(context.issueTrackAlias() == 2)
    }

    @Test func resolvePublishRequestReturnsPublishedTrack() async throws {
        let context: SessionContext = .init(connection: MockTransportConnection(), controlStream: MockTransportBiStream())
        let publishedTrack: PublishedTrack = .init(
            requestID: 2,
            resource: .init(trackNamespace: .init(strings: ["live"]), trackName: Data("video".utf8)),
            trackAlias: 3,
            groupOrder: .ascending,
            contentExist: .noContent,
            forward: true
        )

        let task: Task<PublishedTrack, Error> = .init {
            try await withCheckedThrowingContinuation { continuation in
                context.addPublishRequest(2, publishedTrack: publishedTrack, continuation: continuation)
                context.resolvePublishRequest(
                    with: .init(
                        requestID: 2,
                        forward: true,
                        subscriberPriority: 0,
                        groupOrder: .ascending,
                        filter: .largestObject,
                        deliveryTimeout: nil
                    )
                )
            }
        }

        let result: PublishedTrack = try await task.value
        #expect(result.trackAlias == 3)
    }

    @Test func rejectSubscribeRequestThrows() async {
        let context: SessionContext = .init(connection: MockTransportConnection(), controlStream: MockTransportBiStream())
        let task: Task<Subscription, Error> = .init {
            try await withCheckedThrowingContinuation { continuation in
                context.addSubscribeRequest(
                    4,
                    resource: .init(trackNamespace: .init(strings: ["live"]), trackName: Data("audio".utf8)),
                    subscriberPriority: 0,
                    requestedGroupOrder: .ascending,
                    forward: true,
                    filter: .largestObject,
                    continuation: continuation
                )
                context.rejectSubscribeRequest(with: .init(requestID: 4, errorCode: 5, reasonPhrase: "rejected"))
            }
        }

        await #expect(throws: SubscribeError.self) {
            try await task.value
        }
    }
}
