//
//  SampleConfiguration.swift
//  Sample
//
//  Created by Codex on 2026/04/11.
//

import Foundation
import Moqintosh

struct SampleConfiguration {

    struct LatencyPayload: Codable {

        let sentAtMilliseconds: Int64
    }

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
        namespace.joinedUTF8Elements()
    }

    func makeTrackResource(namespace: TrackNamespace, trackName: String) -> TrackResource? {
        let trimmedTrackName: String = trackName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTrackName.isEmpty else { return nil }
        return TrackResource(
            trackNamespace: namespace,
            trackName: Data(trimmedTrackName.utf8)
        )
    }

    func makePayload(date: Date = Date()) -> ReadOnlyBytes {
        let payload: LatencyPayload = LatencyPayload(
            sentAtMilliseconds: Int64(date.timeIntervalSince1970 * 1_000)
        )
        let encoder: JSONEncoder = JSONEncoder()
        guard let data: Data = try? encoder.encode(payload) else {
            preconditionFailure("Failed to encode LatencyPayload")
        }
        return ReadOnlyBytes(data)
    }

    func decodePayload(_ data: Data) -> LatencyPayload? {
        let decoder: JSONDecoder = JSONDecoder()
        return try? decoder.decode(LatencyPayload.self, from: data)
    }

    func decodePayload(_ bytes: ReadOnlyBytes) -> LatencyPayload? {
        decodePayload(bytes.materialize())
    }

    func makeLatencyText(sentAtMilliseconds: Int64, receivedAt: Date = Date()) -> String {
        let receivedAtMilliseconds: Int64 = Int64(receivedAt.timeIntervalSince1970 * 1_000)
        let latencyMilliseconds: Int64 = max(0, receivedAtMilliseconds - sentAtMilliseconds)
        let sentAtDate: Date = Date(timeIntervalSince1970: TimeInterval(sentAtMilliseconds) / 1_000)
        let sentAtText: String = makeDisplayTimestamp(date: sentAtDate)
        return "sentAt=\(sentAtText), latency=\(latencyMilliseconds)ms"
    }

    func makeDisplayTimestamp(date: Date = Date()) -> String {
        ISO8601DateFormatter.string(
            from: date,
            timeZone: .current,
            formatOptions: [.withInternetDateTime, .withFractionalSeconds]
        )
    }
}
