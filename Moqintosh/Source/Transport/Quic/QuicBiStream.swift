//
//  QuicBiStream.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation
import Network

// Safe because the wrapper forwards directly to the underlying Network stream without additional mutable state.
/// A QUIC bidirectional stream.
final class QuicBiStream: TransportBiStream, @unchecked Sendable {

    private let stream: QUIC.Stream<QUICStream>

    init(stream: QUIC.Stream<QUICStream>) {
        self.stream = stream
    }

    func receive() async throws -> Data {
        let data: Data = try await stream.receive(atLeast: 1, atMost: Int.max).content
        OSLogger.trace("BiStream received \(data.count) bytes (streamID: \(stream.streamID))")
        return data
    }

    func send(bytes: Data) async throws {
        OSLogger.trace("BiStream sending \(bytes.count) bytes (streamID: \(stream.streamID))")
        try await stream.send(bytes)
    }
}
