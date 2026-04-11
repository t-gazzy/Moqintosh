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
        let controlStream: MockTransportBiStream = .init()
        let dataStream: MockTransportUniSendStream = .init()
        let connection: MockTransportConnection = .init(
            biStream: controlStream,
            additionalUniSendStreams: [dataStream]
        )
        let context: SessionContext = .init(connection: connection, controlStream: controlStream)
        let receiver: ControlMessageReceiver = .init(controlStream: controlStream, dispatcher: .init(sessionContext: context))
        let session: Session = .init(sessionContext: context, controlMessageReceiver: receiver)
        let factory: StreamSenderFactory = session.makePublisher().makeStreamSenderFactory(
            for: .init(
                requestID: 1,
                resource: .init(trackNamespace: .init(strings: ["live"]), trackName: .init()),
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
