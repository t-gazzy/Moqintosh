//
//  QuicEndpoint.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Network
import Synchronization

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
            var quic = QUIC(alpn: ["moq-00"]).maxDatagramFrameSize(Int(UInt16.max))
            if allowsUntrustedCertificates {
                quic = quic.tls.peerAuthentication(.none)
            }
            return quic
        }
        let didResumeContinuation: Mutex<Bool> = Mutex<Bool>(false)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let _ = connection.onStateUpdate { _, state in
                let resumeIfNeeded: (@Sendable (Result<Void, Error>) -> Void) = { result in
                    let shouldResume: Bool = didResumeContinuation.withLock { hasResumed in
                        guard !hasResumed else {
                            return false
                        }
                        hasResumed = true
                        return true
                    }
                    guard shouldResume else {
                        return
                    }
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                switch state {
                case .ready:
                    OSLogger.info("Connection ready: \(connection)")
                    resumeIfNeeded(.success(()))
                case .failed(let error):
                    OSLogger.error("Connection failed: \(error)")
                    resumeIfNeeded(.failure(error))
                case .cancelled:
                    OSLogger.warn("Connection cancelled")
                    resumeIfNeeded(.failure(CancellationError()))
                default:
                    OSLogger.debug("Connection state changed: \(state)")
                }
            }
            .start()
        }
        OSLogger.info("qqq idle timeout: \(connection.remoteIdleTimeout)")
        return QuicConnection(connection: connection)
    }
}
