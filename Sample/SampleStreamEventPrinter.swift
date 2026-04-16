//
//  SampleStreamEventPrinter.swift
//  Sample
//
//  Created by Codex on 2026/04/11.
//

import Foundation
import Moqintosh

final class SampleStreamEventPrinter: StreamReceiverFactoryDelegate, StreamReceiverDelegate {

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

    func streamReceiverFactory(_ factory: StreamReceiverFactory, didCreate receiver: StreamReceiver) async {
        receiver.delegate = self
        onEvent("Created stream receiver")
    }

    func streamReceiver(_ receiver: StreamReceiver, didReceive object: SubgroupObject) async {
        let timestampText: String = configuration.makeDisplayTimestamp()
        switch object.content {
        case .payload(let payload):
            let text: String = String(data: payload, encoding: .utf8) ?? "<\(payload.count) bytes>"
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

    func streamReceiverDidClose(_ receiver: StreamReceiver) async {
        onEvent("Closed stream receiver")
    }
}
