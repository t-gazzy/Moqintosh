//
//  Endpoint.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// Represents a MOQT endpoint. Use this to create a Session.
public final class Endpoint: Sendable {

    /// The remote MOQT URL.
    public let url: URL

    let host: String
    let port: UInt16

    /// Creates an endpoint for a remote MOQT server.
    public init?(url: URL) {
        guard url.scheme?.lowercased() == "moqt",
              let host: String = url.host,
              !host.isEmpty,
              let urlPort: Int = url.port,
              let port: UInt16 = UInt16(exactly: urlPort) else {
            return nil
        }
        self.url = url
        self.host = host
        self.port = port
    }

    /// Opens a QUIC connection and performs the MOQT session handshake.
    public func connect(allowsUntrustedCertificates: Bool = false) async throws -> Session {
        OSLogger.info("Connecting transport to \(url.absoluteString)")
        let transportEndpoint = QuicEndpoint(host: host, port: port, allowsUntrustedCertificates: allowsUntrustedCertificates)
        let factory: SessionFactory = SessionFactory()
        return try await factory.connect(transportEndpoint: transportEndpoint)
    }
}
