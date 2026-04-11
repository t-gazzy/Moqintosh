//
//  FetchObjectFrameReaderTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/12.
//

import Foundation
import Testing
@testable import Moqintosh

struct FetchObjectFrameReaderTests {

    @Test func readObjectWhenPayloadIsFragmentedAcrossMultipleChunks() async throws {
        let encodedObject: Data = makeFetchObjectBytes(
            groupID: 4,
            subgroupID: 5,
            objectID: 6,
            publisherPriority: 7,
            payload: Data("abcdef".utf8)
        )
        let chunks: [TransportUniReceiveResult] = encodedObject.map { byte in
            TransportUniReceiveResult(bytes: Data([byte]), isComplete: false)
        }
        let stream: MockTransportUniReceiveStream = MockTransportUniReceiveStream(receiveQueue: chunks, receiveError: nil)
        let reader: FetchObjectFrameReader = FetchObjectFrameReader()

        let decoded: SubgroupObject = try await reader.read(from: stream)

        #expect(decoded.groupID == 4)
        #expect(decoded.objectID == 6)
        if case .payload(let payload) = decoded.content {
            #expect(payload == Data("abcdef".utf8))
        } else {
            Issue.record("Expected payload content")
        }
    }

    @Test func readSequentialObjectsPreservesTrailingBytesInBuffer() async throws {
        let firstObject: Data = makeFetchObjectBytes(
            groupID: 4,
            subgroupID: 5,
            objectID: 6,
            publisherPriority: 7,
            payload: Data("abc".utf8)
        )
        let secondObject: Data = makeFetchObjectBytes(
            groupID: 4,
            subgroupID: 5,
            objectID: 7,
            publisherPriority: 7,
            payload: Data("xyz".utf8)
        )
        let stream: MockTransportUniReceiveStream = MockTransportUniReceiveStream(
            receiveQueue: [
                TransportUniReceiveResult(bytes: firstObject + secondObject.prefix(2), isComplete: false),
                TransportUniReceiveResult(bytes: Data(secondObject.dropFirst(2)), isComplete: false)
            ],
            receiveError: nil
        )
        let reader: FetchObjectFrameReader = FetchObjectFrameReader()

        let firstDecoded: SubgroupObject = try await reader.read(from: stream)
        let secondDecoded: SubgroupObject = try await reader.read(from: stream)

        #expect(firstDecoded.objectID == 6)
        #expect(secondDecoded.objectID == 7)
        if case .payload(let payload) = secondDecoded.content {
            #expect(payload == Data("xyz".utf8))
        } else {
            Issue.record("Expected payload content")
        }
    }
}

private func makeFetchObjectBytes(
    groupID: UInt64,
    subgroupID: UInt64,
    objectID: UInt64,
    publisherPriority: UInt8,
    payload: Data
) -> Data {
    var data: Data = Data()
    data.writeVarint(groupID)
    data.writeVarint(subgroupID)
    data.writeVarint(objectID)
    data.append(publisherPriority)
    data.writeVarint(0)
    data.writeVarint(UInt64(payload.count))
    data.append(payload)
    return data
}
