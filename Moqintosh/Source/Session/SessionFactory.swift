//
//  SessionFactory.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

/// Creates a Session by performing the MOQT handshake over a transport connection.
final class SessionFactory {
    func connect(transportEndpoint: TransportEndpoint) async throws -> Session {
        OSLogger.info("Connecting transport")
        let connection = try await transportEndpoint.connect()

        OSLogger.debug("Opening control stream")
        let controlStream = try await connection.openBiStream()

        let handshaker = SessionHandshaker(stream: controlStream)
        let serverSetup = try await handshaker.handshake()
        OSLogger.info("Handshake completed (selectedVersion: \(serverSetup.selectedVersion))")

        let maxRequestID: UInt64 = serverSetup.parameters.compactMap { parameter in
            if case .maxRequestId(let value) = parameter {
                return value
            }
            return nil
        }.max() ?? 0

        let context = SessionContext(
            connection: connection,
            controlStream: controlStream,
            remoteMaxRequestID: maxRequestID
        )
        let receiver = ControlMessageReceiver(controlStream: controlStream)
        return Session(sessionContext: context, controlMessageReceiver: receiver)
    }
}
