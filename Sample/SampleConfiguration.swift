//
//  SampleConfiguration.swift
//  Sample
//
//  Created by Codex on 2026/04/11.
//

import Foundation
import Moqintosh

struct SampleConfiguration {

    let defaultPort: UInt16

    init(defaultPort: UInt16 = 4434) {
        self.defaultPort = defaultPort
    }

    func makeEndpoint(from addressText: String) -> Endpoint? {
        let trimmedAddress: String = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else { return nil }
        let components: [String] = trimmedAddress.split(separator: ":", maxSplits: 1).map(String.init)
        let host: String = components[0]
        let port: UInt16
        if components.count == 2 {
            guard let parsedPort: UInt16 = UInt16(components[1]) else { return nil }
            port = parsedPort
        } else {
            port = defaultPort
        }
        return Endpoint(host: host, port: port)
    }

    func makeNamespace(from text: String) -> TrackNamespace? {
        let elements: [String] = text
            .split(separator: "/")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !elements.isEmpty else { return nil }
        return TrackNamespace(strings: elements)
    }

    func makeNamespaceString(from namespace: TrackNamespace) -> String {
        namespace.elements
            .map { String(data: $0, encoding: .utf8) ?? "<binary>" }
            .joined(separator: "/")
    }

    func makeTrackResource(namespace: TrackNamespace, trackName: String) -> TrackResource? {
        let trimmedTrackName: String = trackName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTrackName.isEmpty else { return nil }
        return TrackResource(
            trackNamespace: namespace,
            trackName: Data(trimmedTrackName.utf8)
        )
    }

    func makePayload(date: Date = Date()) -> Data {
        let timestamp: String = ISO8601DateFormatter.string(
            from: date,
            timeZone: .current,
            formatOptions: [.withInternetDateTime, .withFractionalSeconds]
        )
        return Data(timestamp.utf8)
    }

    func makeDisplayTimestamp(date: Date = Date()) -> String {
        ISO8601DateFormatter.string(
            from: date,
            timeZone: .current,
            formatOptions: [.withInternetDateTime, .withFractionalSeconds]
        )
    }
}
