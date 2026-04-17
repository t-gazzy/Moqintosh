//
//  FetchSenderTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/12.
//

import Foundation
import Testing
@testable import Moqintosh

struct FetchSenderTests {

    @Test func sendEncodesObjectAndEndsFetch() async throws {
        let stream: MockTransportUniSendStream = MockTransportUniSendStream()
        let sender: FetchSender = try await FetchSender(stream: stream, requestID: 9)

        try await sender.send(
            groupID: 2,
            subgroupID: 3,
            objectID: 4,
            publisherPriority: 5,
            endOfFetch: true,
            content: .payload(Data("ab".utf8))
        )

        #expect(stream.sentBytes.count == 2)
        #expect(stream.endOfStreamFlags == [false, true])
        #expect(stream.sentBytes[0] == FetchHeader(requestID: 9).encode())

        let reader: FetchObjectFrameReader = FetchObjectFrameReader(initialData: stream.sentBytes[1])
        let object: SubgroupObject = try await reader.read(from: MockTransportUniReceiveStream(receiveQueue: [], receiveError: nil))
        #expect(object.groupID == 2)
        #expect(object.objectID == 4)
        if case .payload(let payload) = object.content {
            #expect(payload.equals(Data("ab".utf8)))
        } else {
            Issue.record("Expected payload content")
        }
    }
}
