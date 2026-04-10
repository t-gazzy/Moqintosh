//
//  QuicConnection.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Network

/// An established QUIC transport connection.
final class QuicConnection: TransportConnection {

    let connection: NetworkConnection<QUIC>
    weak var delegate: (any TransportConnectionDelegate)?

    init(connection: NetworkConnection<QUIC>) {
        self.connection = connection
        Task { [weak self] in
            guard let self else { return }
            try await connection.inboundStreams { [weak self] stream in
                guard let self else { return }
                guard stream.directionality == .unidirectional else {
                    OSLogger.warn("Received bidirectional inbound stream — ignored (streamID: \(stream.streamID))")
                    return
                }
                OSLogger.debug("Received inbound UniStream (streamID: \(stream.streamID))")
                delegate?.connection(self, didReceiveUniStream: QuicUniStream(stream: stream))
            }
        }
    }

    func openBiStream() async throws -> TransportBiStream {
        OSLogger.debug("Opening bidirectional stream")
        let stream = try await connection.openStream(directionality: .bidirectional)
        OSLogger.debug("Opened bidirectional stream (streamID: \(stream.streamID))")
        return QuicBiStream(stream: stream)
    }

    func openUniStream() async throws -> TransportUniStream {
        OSLogger.debug("Opening unidirectional stream")
        let stream = try await connection.openStream(directionality: .unidirectional)
        OSLogger.debug("Opened unidirectional stream (streamID: \(stream.streamID))")
        return QuicUniStream(stream: stream)
    }
}
