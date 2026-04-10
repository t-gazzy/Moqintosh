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
    private var delegate: SessionHandshakerDelegate?

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
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = SessionHandshakerDelegate(continuation: continuation)
            self.delegate = delegate
            stream.delegate = delegate
        }
    }
}

// MARK: - Private

private final class SessionHandshakerDelegate: TransportBiStreamDelegate {

    private let continuation: CheckedContinuation<ServerSetupMessage, Error>
    private var buffer: Data = .init()

    init(continuation: CheckedContinuation<ServerSetupMessage, Error>) {
        self.continuation = continuation
    }

    func stream(_ stream: TransportBiStream, didReceive bytes: Data) {
        buffer.append(bytes)
        guard let message = try? ServerSetupMessage.decode(from: buffer) else { return }
        OSLogger.info("Received SERVER_SETUP (selectedVersion: \(message.selectedVersion))")
        continuation.resume(returning: message)
    }
}
