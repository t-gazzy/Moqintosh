//
//  QuicBiStream.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation
import Network

/// A QUIC bidirectional stream.
final class QuicBiStream: TransportBiStream {

    private let stream: QUIC.Stream<QUICStream>
    weak var delegate: (any TransportBiStreamDelegate)?

    init(stream: QUIC.Stream<QUICStream>) {
        self.stream = stream
        Task { [weak self] in
            guard let self else { return }
            while let data = try? await stream.receive(atLeast: 1, atMost: Int.max).content {
                OSLogger.trace("BiStream received \(data.count) bytes (streamID: \(stream.streamID))")
                delegate?.stream(self, didReceive: data)
            }
            OSLogger.debug("BiStream receive loop ended (streamID: \(stream.streamID))")
        }
    }

    func send(bytes: Data) async throws {
        OSLogger.trace("BiStream sending \(bytes.count) bytes (streamID: \(stream.streamID))")
        try await stream.send(bytes)
    }
}
