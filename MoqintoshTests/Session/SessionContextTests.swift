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

    @Test func issueRequestIDIncrementsByTwo() async throws {
        let context: SessionContext = SessionContext(
            connection: MockTransportConnection(),
            controlStream: MockTransportBiStream(),
            remoteMaxRequestID: 4
        )
        #expect(try await context.issueRequestID() == 0)
        #expect(try await context.issueRequestID() == 2)
        #expect(try await context.issueRequestID() == 4)
    }

    @Test func issueRequestIDSendsRequestsBlockedWhenRemoteLimitIsReached() async {
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(
            connection: MockTransportConnection(),
            controlStream: stream,
            remoteMaxRequestID: 0
        )

        _ = try? await context.issueRequestID()

        await #expect(throws: SessionFlowControlError.self) {
            try await context.issueRequestID()
        }
        #expect(stream.sentBytes.count == 1)
        #expect(stream.sentBytes[0].first == UInt8(MessageType.requestsBlocked.rawValue))
    }

    @Test func issueTrackAliasIncrementsByOne() {
        let context: SessionContext = SessionContext(connection: MockTransportConnection(), controlStream: MockTransportBiStream())
        #expect(context.issueTrackAlias() == 0)
        #expect(context.issueTrackAlias() == 1)
        #expect(context.issueTrackAlias() == 2)
    }

    @Test func resolvePublishRequestReturnsPublishedTrack() async throws {
        let context: SessionContext = SessionContext(connection: MockTransportConnection(), controlStream: MockTransportBiStream())
        let publishedTrack: PublishedTrack = PublishedTrack(
            requestID: 2,
            resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("video".utf8)),
            trackAlias: 3,
            groupOrder: .ascending,
            contentExist: .noContent,
            forward: true
        )

        let task: Task<PublishedTrack, Error> = .init {
            try await withCheckedThrowingContinuation { continuation in
                context.requestStore.addPublishRequest(2, publishedTrack: publishedTrack, continuation: continuation)
                context.requestStore.resolvePublishRequest(
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
        let context: SessionContext = SessionContext(connection: MockTransportConnection(), controlStream: MockTransportBiStream())
        let task: Task<Subscription, Error> = .init {
            try await withCheckedThrowingContinuation { continuation in
                context.requestStore.addSubscribeRequest(
                    4,
                    resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("audio".utf8)),
                    subscriberPriority: 0,
                    requestedGroupOrder: .ascending,
                    forward: true,
                    filter: .largestObject,
                    continuation: continuation
                )
                context.requestStore.rejectSubscribeRequest(with: .init(requestID: 4, errorCode: 5, reasonPhrase: "rejected"))
            }
        }

        await #expect(throws: SubscribeError.self) {
            try await task.value
        }
    }
}
