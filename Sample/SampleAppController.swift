//
//  SampleAppController.swift
//  Sample
//
//  Created by Codex on 2026/04/11.
//

import Observation
import Moqintosh

@MainActor
@Observable
final class SampleAppController {

    var destinationText: String
    var statusText: String
    var isConnecting: Bool
    var sessionController: SampleSessionController?

    private let configuration: SampleConfiguration

    init(configuration: SampleConfiguration = .init()) {
        self.destinationText = "localhost:4434"
        self.statusText = ""
        self.isConnecting = false
        self.sessionController = nil
        self.configuration = configuration
    }

    func connect() async {
        guard !isConnecting else { return }
        guard let endpoint: Endpoint = configuration.makeEndpoint(from: destinationText) else {
            statusText = "Invalid destination address"
            return
        }
        isConnecting = true
        statusText = "Connecting..."
        do {
            let session: Session = try await endpoint.connect(allowsUntrustedCertificates: true)
            sessionController = .init(session: session, configuration: configuration)
            statusText = "Connected"
        } catch {
            statusText = "Connection failed: \(error.localizedDescription)"
        }
        isConnecting = false
    }
}
