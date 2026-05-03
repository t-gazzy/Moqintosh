//
//  SampleStreamEventPrinter.swift
//  Sample
//
//  Created by Codex on 2026/04/11.
//

import Foundation
import Moqintosh

final class SampleStreamEventPrinter: Sendable {

    private let configuration: SampleConfiguration
    private let onEvent: @Sendable (String) -> Void
    private let onReceivedData: @Sendable (String) -> Void

    init(
        configuration: SampleConfiguration,
        onEvent: @escaping @Sendable (String) -> Void,
        onReceivedData: @escaping @Sendable (String) -> Void
    ) {
        self.configuration = configuration
        self.onEvent = onEvent
        self.onReceivedData = onReceivedData
    }

    func receive(from factory: StreamReceiverFactory) async {
        while !Task.isCancelled, let receiver: StreamReceiver = await factory.accept() {
            onEvent("Created stream receiver")
            Task { [weak self, receiver] in
                await self?.receive(from: receiver)
            }
        }
    }

    private func receive(from receiver: StreamReceiver) async {
        do {
            while !Task.isCancelled, let object: SubgroupObject = try await receiver.receive() {
                print(object: object)
            }
        } catch is CancellationError {
            return
        } catch {
            onEvent("Stream receiver failed: \(error)")
        }
        guard !Task.isCancelled else { return }
        onEvent("Closed stream receiver")
    }

    private func print(object: SubgroupObject) {
        let receivedAt: Date = Date()
        let timestampText: String = configuration.makeDisplayTimestamp(date: receivedAt)
        switch object.content {
        case .payload(let payload):
            let text: String
            if let decodedPayload: SampleConfiguration.LatencyPayload = configuration.decodePayload(payload) {
                text = configuration.makeLatencyText(
                    sentAtMilliseconds: decodedPayload.sentAtMilliseconds,
                    receivedAt: receivedAt
                )
            } else {
                text = payload.utf8String ?? "<\(payload.data.count) bytes>"
            }
            onReceivedData(
                "[\(timestampText)] Stream [group: \(object.groupID), object: \(object.objectID)]: \(text)"
            )
        case .status(let status):
            onReceivedData(
                "[\(timestampText)] Stream status [group: \(object.groupID), object: \(object.objectID)]: \(status)"
            )
        @unknown default:
            onReceivedData(
                "[\(timestampText)] Stream [group: \(object.groupID), object: \(object.objectID)]: <unknown>"
            )
        }
    }
}
