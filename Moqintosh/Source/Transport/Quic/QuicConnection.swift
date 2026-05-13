//
//  QuicConnection.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Network
import Foundation
import Synchronization

/// An established QUIC transport connection.
final class QuicConnection: TransportConnection, Sendable {

    private struct DelegateStorage {
        weak var delegate: (any TransportConnectionDelegate)?
    }

    let connection: NetworkConnection<QUIC>
    private let delegateStorage: Mutex<DelegateStorage>

    var delegate: (any TransportConnectionDelegate)? {
        get {
            delegateStorage.withLock { storage in
                storage.delegate
            }
        }
        set {
            delegateStorage.withLock { storage in
                storage.delegate = newValue
            }
        }
    }

    init(connection: NetworkConnection<QUIC>) {
        self.connection = connection
        self.delegateStorage = Mutex<DelegateStorage>(DelegateStorage(delegate: nil))
        Task { [weak self] in
            guard let self else { return }
            try await connection.inboundStreams { [weak self] stream in
                guard let self else { return }
                guard stream.directionality == .unidirectional else {
                    OSLogger.warn("Received bidirectional inbound stream — ignored (streamID: \(stream.streamID))")
                    return
                }
                OSLogger.debug("Received inbound UniStream (streamID: \(stream.streamID))")
                let delegate: (any TransportConnectionDelegate)? = self.delegate
                delegate?.connection(self, didReceiveUniStream: QuicUniReceiveStream(stream: stream))
            }
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                let datagrams: QUIC.Datagrams<QUICDatagram> = try await connection.datagrams
                for try await message in datagrams.messages {
                    OSLogger.debug("Received inbound datagram")
                    let delegate: (any TransportConnectionDelegate)? = self.delegate
                    delegate?.connection(self, didReceiveDatagram: message.content)
                }
            } catch {
                OSLogger.warn("Datagram receive loop stopped: \(error)")
            }
        }
    }

    func openBiStream() async throws -> TransportBiStream {
        OSLogger.debug("Opening bidirectional stream")
        let stream = try await connection.openStream(directionality: .bidirectional)
        OSLogger.debug("Opened bidirectional stream (streamID: \(stream.streamID))")
        return QuicBiStream(stream: stream)
    }

    func openUniStream() async throws -> TransportUniSendStream {
        OSLogger.debug("Opening unidirectional stream")
        let stream = try await connection.openStream(directionality: .unidirectional)
        OSLogger.debug("Opened unidirectional stream (streamID: \(stream.streamID))")
        return QuicUniSendStream(stream: stream)
    }

    func sendDatagram(bytes: Data) async throws {
        let datagrams: QUIC.Datagrams<QUICDatagram> = try await connection.datagrams
        try await datagrams.send(bytes)
    }
}
