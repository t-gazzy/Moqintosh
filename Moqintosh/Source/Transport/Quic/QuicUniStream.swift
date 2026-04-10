//
//  QuicUniStream.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation
import Network

/// A QUIC unidirectional stream.
final class QuicUniStream: TransportUniStream {

    private let stream: QUIC.Stream<QUICStream>

    init(stream: QUIC.Stream<QUICStream>) {
        self.stream = stream
    }

    func send(bytes: Data) async throws {
        OSLogger.trace("UniStream sending \(bytes.count) bytes (streamID: \(stream.streamID))")
        try await stream.send(bytes)
    }
}
