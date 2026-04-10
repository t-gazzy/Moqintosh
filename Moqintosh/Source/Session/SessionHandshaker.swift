//
//  SessionHandshaker.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// Performs the MOQT session handshake over a bidirectional control stream.
/// Sends CLIENT_SETUP and waits for SERVER_SETUP.
final class SessionHandshaker {

    private let stream: TransportBiStream
    private let frameReader = MessageFrameReader()

    init(stream: TransportBiStream) {
        self.stream = stream
    }

    func handshake() async throws -> ServerSetupMessage {
        let clientSetup = ClientSetupMessage(
            supportedVersions: [0xff00000E],
            parameters: [
                .maxRequestId(0),
                .moqtImplementation("Moqintosh")
            ]
        )
        OSLogger.debug("Sending CLIENT_SETUP (versions: \(clientSetup.supportedVersions))")
        try await stream.send(bytes: clientSetup.encode())

        OSLogger.debug("Waiting for SERVER_SETUP")
        let message = try await frameReader.read(from: stream)
        guard case .serverSetup(let serverSetup) = message else {
            throw SessionHandshakerError.unexpectedMessage(message)
        }
        OSLogger.info("Received SERVER_SETUP (selectedVersion: \(serverSetup.selectedVersion))")
        return serverSetup
    }
}

enum SessionHandshakerError: Error {
    case unexpectedMessage(MOQTMessage)
}
