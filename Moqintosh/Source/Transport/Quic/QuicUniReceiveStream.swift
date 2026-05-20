//
//  QuicUniReceiveStream.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Network

/// An inbound QUIC unidirectional stream.
final class QuicUniReceiveStream: TransportUniReceiveStream, Sendable {

    private static let maximumReceiveByteCount: Int = 64 * 1024

    private let stream: QUIC.Stream<QUICStream>

    init(stream: QUIC.Stream<QUICStream>) {
        self.stream = stream
    }

    func receive() async throws -> TransportUniReceiveResult {
        let message = try await stream.receive(atLeast: 1, atMost: Self.maximumReceiveByteCount)
        OSLogger.trace(
            "UniStream received \(message.content.count) bytes (streamID: \(stream.streamID), isComplete: \(message.metadata.endOfStream))"
        )
        return TransportUniReceiveResult(bytes: Data(message.content), isComplete: message.metadata.endOfStream)
    }
}
