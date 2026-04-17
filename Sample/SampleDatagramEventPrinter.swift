//
//  SampleDatagramEventPrinter.swift
//  Sample
//
//  Created by Codex on 2026/04/11.
//

import Foundation
import Moqintosh

final class SampleDatagramEventPrinter: DatagramReceiverDelegate {

    private let configuration: SampleConfiguration
    private let onReceivedData: @Sendable (String) -> Void

    init(configuration: SampleConfiguration, onReceivedData: @escaping @Sendable (String) -> Void) {
        self.configuration = configuration
        self.onReceivedData = onReceivedData
    }

    func datagramReceiver(_ receiver: DatagramReceiver, didReceive datagram: ObjectDatagram) {
        let receivedAt: Date = Date()
        let timestampText: String = configuration.makeDisplayTimestamp(date: receivedAt)
        let objectIDText: String
        switch datagram.objectID {
        case .none:
            objectIDText = "none"
        case .explicit(let objectID):
            objectIDText = String(objectID)
        @unknown default:
            objectIDText = "unknown"
        }
        switch datagram.content {
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
                "[\(timestampText)] Datagram [group: \(datagram.groupID), object: \(objectIDText)]: \(text)"
            )
        case .status(let status):
            onReceivedData(
                "[\(timestampText)] Datagram status [group: \(datagram.groupID), object: \(objectIDText)]: \(status)"
            )
        @unknown default:
            onReceivedData(
                "[\(timestampText)] Datagram [group: \(datagram.groupID), object: \(objectIDText)]: <unknown>"
            )
        }
    }
}
