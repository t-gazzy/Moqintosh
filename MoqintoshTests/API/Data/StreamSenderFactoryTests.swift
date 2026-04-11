//
//  StreamSenderFactoryTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Testing
@testable import Moqintosh

struct StreamSenderFactoryTests {

    @Test func makeSenderOpensStreamAndSendsHeader() async throws {
        let controlStream: MockTransportBiStream = MockTransportBiStream()
        let dataStream: MockTransportUniSendStream = MockTransportUniSendStream()
        let connection: MockTransportConnection = MockTransportConnection(
            biStream: controlStream,
            additionalUniSendStreams: [dataStream]
        )
        let context: SessionContext = SessionContext(connection: connection, controlStream: controlStream)
        let receiver: ControlMessageReceiver = ControlMessageReceiver(controlStream: controlStream, dispatcher: ControlMessageDispatcher(sessionContext: context))
        let session: Session = Session(sessionContext: context, controlMessageReceiver: receiver)
        let factory: StreamSenderFactory = session.makePublisher().makeStreamSenderFactory(
            for: PublishedTrack(
                requestID: 1,
                resource: TrackResource(trackNamespace: TrackNamespace(strings: ["live"]), trackName: Data()),
                trackAlias: 9,
                groupOrder: .ascending,
                contentExist: .noContent,
                forward: true
            )
        )

        let sender: StreamSender = try await factory.makeSender(
            groupID: 2,
            subgroupID: .explicit(3),
            publisherPriority: 4
        )
        _ = sender
        #expect(factory.publishedTrack.trackAlias == 9)
        #expect(dataStream.sentBytes.count == 1)
        #expect(dataStream.endOfStreamFlags == [false])
        #expect(dataStream.sentBytes[0].first == UInt8(0x14))
    }
}
