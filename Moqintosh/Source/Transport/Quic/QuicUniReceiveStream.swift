//
//  QuicUniReceiveStream.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Network

/// An inbound QUIC unidirectional stream.
final class QuicUniReceiveStream: TransportUniReceiveStream {

    private let stream: QUIC.Stream<QUICStream>

    init(stream: QUIC.Stream<QUICStream>) {
        self.stream = stream
    }

    func receive() async throws -> TransportUniReceiveResult {
        let message = try await stream.receive(atLeast: 1, atMost: Int.max)
        OSLogger.trace(
            "UniStream received \(message.content.count) bytes (streamID: \(stream.streamID), isComplete: \(message.metadata.endOfStream))"
        )
        return .init(bytes: Data(message.content), isComplete: message.metadata.endOfStream)
    }
}
