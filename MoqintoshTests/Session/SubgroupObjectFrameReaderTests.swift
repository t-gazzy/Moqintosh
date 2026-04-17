//
//  SubgroupObjectFrameReaderTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/12.
//

import Foundation
import Testing
@testable import Moqintosh

struct SubgroupObjectFrameReaderTests {

    @Test func readObjectWhenPayloadIsFragmentedAcrossMultipleChunks() async throws {
        let header: SubgroupHeader = SubgroupHeader(
            trackAlias: 1,
            groupID: 2,
            subgroupID: .explicit(3),
            publisherPriority: 4
        )
        let object: SubgroupObject = header.makeObject(objectID: 5, content: .payload(ReadOnlyBytes(Data("abcdef".utf8))))
        let chunks: [TransportUniReceiveResult] = object.encode().map { byte in
            TransportUniReceiveResult(bytes: Data([byte]), isComplete: false)
        }
        let stream: MockTransportUniReceiveStream = MockTransportUniReceiveStream(receiveQueue: chunks, receiveError: nil)
        let reader: SubgroupObjectFrameReader = SubgroupObjectFrameReader(header: header)

        let decoded: SubgroupObject = try await reader.read(from: stream)

        #expect(decoded.objectID == 5)
        if case .payload(let payload) = decoded.content {
            #expect(payload.equals(Data("abcdef".utf8)))
        } else {
            Issue.record("Expected payload content")
        }
    }

    @Test func readSequentialObjectsPreservesTrailingBytesInBuffer() async throws {
        let header: SubgroupHeader = SubgroupHeader(
            trackAlias: 1,
            groupID: 2,
            subgroupID: .explicit(3),
            publisherPriority: 4
        )
        let firstObject: SubgroupObject = header.makeObject(objectID: 5, content: .payload(ReadOnlyBytes(Data("abc".utf8))))
        let secondObject: SubgroupObject = header.makeObject(
            previousObjectID: 5,
            objectID: 6,
            content: .payload(ReadOnlyBytes(Data("xyz".utf8)))
        )
        let secondEncoded: Data = secondObject.encode()
        let stream: MockTransportUniReceiveStream = MockTransportUniReceiveStream(
            receiveQueue: [
                TransportUniReceiveResult(
                    bytes: firstObject.encode() + secondEncoded.prefix(2),
                    isComplete: false
                ),
                TransportUniReceiveResult(
                    bytes: Data(secondEncoded.dropFirst(2)),
                    isComplete: false
                )
            ],
            receiveError: nil
        )
        let reader: SubgroupObjectFrameReader = SubgroupObjectFrameReader(header: header)

        let firstDecoded: SubgroupObject = try await reader.read(from: stream)
        let secondDecoded: SubgroupObject = try await reader.read(from: stream)

        #expect(firstDecoded.objectID == 5)
        #expect(secondDecoded.objectID == 6)
        if case .payload(let payload) = secondDecoded.content {
            #expect(payload.equals(Data("xyz".utf8)))
        } else {
            Issue.record("Expected payload content")
        }
    }
}
