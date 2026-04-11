//
//  StreamSenderTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct StreamSenderTests {

    @Test func sendEncodesSequentialObjectsWithDeltas() async throws {
        let stream: MockTransportUniStream = .init()
        let sender: StreamSender = .init(
            stream: stream,
            header: .init(
                trackAlias: 1,
                groupID: 2,
                subgroupID: .explicit(3),
                publisherPriority: 4
            )
        )

        try await sender.send(objectID: 7, content: .payload(Data("ab".utf8)))
        try await sender.send(objectID: 8, content: .status(9))

        #expect(stream.sentBytes.count == 2)

        let firstObject: SubgroupObject = try .decode(stream.sentBytes[0], header: .init(
            trackAlias: 1,
            groupID: 2,
            subgroupID: .explicit(3),
            publisherPriority: 4
        ))
        #expect(firstObject.objectID == 7)

        let secondObject: SubgroupObject = try .decode(
            stream.sentBytes[1],
            header: .init(
                trackAlias: 1,
                groupID: 2,
                subgroupID: .explicit(3),
                publisherPriority: 4
            ),
            previousObjectID: 7
        )
        #expect(secondObject.objectID == 8)
        if case .status(let status) = secondObject.content {
            #expect(status == 9)
        } else {
            Issue.record("Expected status content")
        }
    }
}
