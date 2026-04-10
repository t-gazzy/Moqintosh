//
//  QuicEndpoint.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Network

/// QUIC-based transport endpoint using Network.framework with ALPN set to "moq-00".
final class QuicEndpoint: TransportEndpoint {

    private let endpoint: NWEndpoint
    private let allowsUntrustedCertificates: Bool

    init(host: String, port: UInt16, allowsUntrustedCertificates: Bool = false) {
        endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!
        )
        self.allowsUntrustedCertificates = allowsUntrustedCertificates
    }

    func connect() async throws -> TransportConnection {
        OSLogger.info("Connecting to \(endpoint)")
        let allowsUntrustedCertificates: Bool = allowsUntrustedCertificates
        let connection = NetworkConnection(to: endpoint) {
            var quic = QUIC(alpn: ["moq-00"])
            if allowsUntrustedCertificates {
                quic = quic.tls.peerAuthentication(.none)
            }
            return quic
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let _ = connection.onStateUpdate { _, state in
                switch state {
                case .ready:
                    OSLogger.info("Connection ready: \(connection)")
                    continuation.resume()
                case .failed(let error):
                    OSLogger.error("Connection failed: \(error)")
                    continuation.resume(throwing: error)
                case .cancelled:
                    OSLogger.warn("Connection cancelled")
                    continuation.resume(throwing: CancellationError())
                default:
                    OSLogger.debug("Connection state changed: \(state)")
                }
            }
            .start()
        }
        return QuicConnection(connection: connection)
    }
}
