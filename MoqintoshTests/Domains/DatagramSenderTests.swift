//
//  DatagramSenderTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct DatagramSenderTests {

    @Test func sendEncodesObjectDatagramForPublishedTrack() async throws {
        let controlStream: MockTransportBiStream = .init()
        let connection: MockTransportConnection = .init(biStream: controlStream)
        let context: SessionContext = .init(connection: connection, controlStream: controlStream)
        let receiver: ControlMessageReceiver = .init(controlStream: controlStream, dispatcher: .init(sessionContext: context))
        let session: Session = .init(sessionContext: context, controlMessageReceiver: receiver)
        let sender: DatagramSender = session.makePublisher().makeDatagramSender(
            for: .init(
                requestID: 1,
                resource: .init(trackNamespace: .init(strings: ["live"]), trackName: Data("video".utf8)),
                trackAlias: 7,
                groupOrder: .ascending,
                contentExist: .noContent,
                forward: true
            )
        )

        try await sender.send(
            groupID: 8,
            objectID: .explicit(9),
            publisherPriority: 10,
            endOfGroup: true,
            content: .payload(Data("abc".utf8))
        )

        #expect(connection.sentDatagrams.count == 1)
        let datagram: ObjectDatagram = try .decode(connection.sentDatagrams[0])
        #expect(datagram.trackAlias == 7)
        #expect(datagram.groupID == 8)
        #expect(datagram.publisherPriority == 10)
        #expect(datagram.endOfGroup == true)
        if case .explicit(let objectID) = datagram.objectID {
            #expect(objectID == 9)
        } else {
            Issue.record("Expected an explicit object ID")
        }
    }
}
