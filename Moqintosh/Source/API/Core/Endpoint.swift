//
//  Endpoint.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

/// Represents a MOQT endpoint. Use this to create a Session.
public final class Endpoint: Sendable {

    public let host: String
    public let port: UInt16

    public init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }

    public func connect(allowsUntrustedCertificates: Bool = false) async throws -> Session {
        OSLogger.info("Connecting transport to \(host):\(port)")
        let transportEndpoint = QuicEndpoint(host: host, port: port, allowsUntrustedCertificates: allowsUntrustedCertificates)
        let factory = SessionFactory()
        return try await factory.connect(transportEndpoint: transportEndpoint)
    }
}
