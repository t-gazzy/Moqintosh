//
//  PublisherTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct PublisherTests {

    @Test func publishNamespaceSendsMessage() async throws {
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: stream)
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)
        let publisher: Publisher = session.makePublisher()

        let task: Task<Void, Error> = .init {
            try await publisher.publishNamespace(trackNamespace: TrackNamespace(strings: ["live"]))
        }

        while stream.sentBytes.isEmpty {
            await Task.yield()
        }
        context.requestStore.resolveRequest(with: PublishNamespaceOKMessage(requestID: 0))
        try await task.value

        let sent: Data = stream.sentBytes[0]
        #expect(sent.first == UInt8(MessageType.publishNamespace.rawValue))
    }

    @Test func publishSendsMessage() async throws {
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: stream)
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)
        let publisher: Publisher = session.makePublisher()

        let task: Task<PublishedTrack, Error> = .init {
            try await publisher.publish(
                resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("video".utf8))
            )
        }

        while stream.sentBytes.isEmpty {
            await Task.yield()
        }
        context.requestStore.resolvePublishRequest(
            with: PublishOKMessage(
                requestID: 0,
                forward: true,
                subscriberPriority: 0,
                groupOrder: .ascending,
                filter: .largestObject,
                deliveryTimeout: nil
            )
        )

        let result: PublishedTrack = try await task.value
        #expect(result.trackAlias == 0)
        #expect(stream.sentBytes[0].first == UInt8(MessageType.publish.rawValue))
    }

    @Test func publishDoneSendsMessage() async throws {
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: stream)
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)
        let publisher: Publisher = session.makePublisher()
        let publishedTrack: PublishedTrack = PublishedTrack(
            requestID: 4,
            resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data("video".utf8)),
            trackAlias: 2,
            groupOrder: .ascending,
            contentExist: .noContent,
            forward: true
        )

        try await publisher.publishDone(for: publishedTrack, statusCode: 0x0, streamCount: 3)

        #expect(stream.sentBytes.count == 1)
        #expect(stream.sentBytes[0].first == UInt8(MessageType.publishDone.rawValue))
    }

    @Test func publishNamespaceDoneSendsMessage() async throws {
        let stream: MockTransportBiStream = MockTransportBiStream()
        let context: SessionContext = SessionContext(connection: MockTransportConnection(biStream: stream), controlStream: stream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: stream)
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)
        let publisher: Publisher = session.makePublisher()

        try await publisher.publishNamespaceDone(trackNamespace: TrackNamespace(strings: ["live"]))

        #expect(stream.sentBytes.count == 1)
        #expect(stream.sentBytes[0].first == UInt8(MessageType.publishNamespaceDone.rawValue))
    }
}
