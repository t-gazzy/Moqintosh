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

    func receive() async throws -> Data {
        let data: Data = try await stream.receive(atLeast: 1, atMost: Int.max).content
        OSLogger.trace("UniStream received \(data.count) bytes (streamID: \(stream.streamID))")
        return data
    }
}
