//
//  QuicUniSendStream.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Network

// Safe because the wrapper forwards directly to the underlying Network stream without additional mutable state.
/// An outbound QUIC unidirectional stream.
final class QuicUniSendStream: TransportUniSendStream, @unchecked Sendable {

    private let stream: QUIC.Stream<QUICStream>

    init(stream: QUIC.Stream<QUICStream>) {
        self.stream = stream
    }

    func send(bytes: Data, endOfStream: Bool) async throws {
        OSLogger.trace(
            "UniStream sending \(bytes.count) bytes (streamID: \(stream.streamID), endOfStream: \(endOfStream))"
        )
        try await stream.send(bytes, endOfStream: endOfStream)
    }
}
