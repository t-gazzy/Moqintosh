//
//  SubgroupObjectFrameReader.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Reassembles subgroup objects from a unidirectional data stream.
///
/// Objects on subgroup streams do not carry an outer length-delimited frame.
/// This reader keeps an internal buffer, pulls more bytes from the stream when
/// needed, and decodes exactly one ``SubgroupObject`` at a time using the
/// subgroup header context.
final class SubgroupObjectFrameReader {

    private let header: SubgroupHeader
    private var buffer: Data
    private var previousObjectID: UInt64?

    init(header: SubgroupHeader, initialData: Data = .init()) {
        self.header = header
        self.buffer = initialData
        self.previousObjectID = nil
    }

    func read(from stream: any TransportUniReceiveStream) async throws -> SubgroupObject {
        while true {
            if let object: SubgroupObject = try extractObject() {
                return object
            }
            buffer.append(try await stream.receive())
        }
    }

    private func extractObject() throws -> SubgroupObject? {
        let reader: ByteReader = .init(data: buffer)
        guard let object: SubgroupObject = try? .decode(
            from: reader,
            header: header,
            previousObjectID: previousObjectID
        ) else {
            return nil
        }
        let consumedBytes: Int = buffer.count - reader.remainingCount
        buffer = Data(buffer.dropFirst(consumedBytes))
        previousObjectID = object.objectID
        return object
    }
}
