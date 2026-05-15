//
//  SampleConfiguration.swift
//  Sample
//
//  Created by Codex on 2026/04/11.
//

import Foundation
import Moqintosh

struct SampleConfiguration: Sendable {

    nonisolated struct LatencyPayload: Codable, Sendable {

        let sentAtMilliseconds: Int64
    }

    nonisolated init() {}

    nonisolated func makeEndpoint(from addressText: String) -> Endpoint? {
        let trimmedAddress: String = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty,
              let url: URL = URL(string: trimmedAddress) else {
            return nil
        }
        return Endpoint(url: url)
    }

    nonisolated func makeNamespace(from text: String) -> TrackNamespace? {
        let elements: [String] = text
            .split(separator: "/")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !elements.isEmpty else { return nil }
        return TrackNamespace(strings: elements)
    }

    nonisolated func makeNamespaceString(from namespace: TrackNamespace) -> String {
        namespace.joinedUTF8Elements()
    }

    nonisolated func makeTrackResource(namespace: TrackNamespace, trackName: String) -> TrackResource? {
        let trimmedTrackName: String = trackName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTrackName.isEmpty else { return nil }
        return TrackResource(
            trackNamespace: namespace,
            trackName: Data(trimmedTrackName.utf8)
        )
    }

    nonisolated func makePayload(date: Date = Date()) -> ReadOnlyBytes {
        let payload: LatencyPayload = LatencyPayload(
            sentAtMilliseconds: Int64(date.timeIntervalSince1970 * 1_000)
        )
        let encoder: JSONEncoder = JSONEncoder()
        guard let data: Data = try? encoder.encode(payload) else {
            preconditionFailure("Failed to encode LatencyPayload")
        }
        return ReadOnlyBytes(data)
    }

    nonisolated func decodePayload(_ data: Data) -> LatencyPayload? {
        let decoder: JSONDecoder = JSONDecoder()
        return try? decoder.decode(LatencyPayload.self, from: data)
    }

    nonisolated func decodePayload(_ bytes: ReadOnlyBytes) -> LatencyPayload? {
        decodePayload(bytes.materialize())
    }

    nonisolated func makeLatencyText(sentAtMilliseconds: Int64, receivedAt: Date = Date()) -> String {
        let receivedAtMilliseconds: Int64 = Int64(receivedAt.timeIntervalSince1970 * 1_000)
        let latencyMilliseconds: Int64 = max(0, receivedAtMilliseconds - sentAtMilliseconds)
        let sentAtDate: Date = Date(timeIntervalSince1970: TimeInterval(sentAtMilliseconds) / 1_000)
        let sentAtText: String = makeDisplayTimestamp(date: sentAtDate)
        return "sentAt=\(sentAtText), latency=\(latencyMilliseconds)ms"
    }

    nonisolated func makeDisplayTimestamp(date: Date = Date()) -> String {
        ISO8601DateFormatter.string(
            from: date,
            timeZone: .current,
            formatOptions: [.withInternetDateTime, .withFractionalSeconds]
        )
    }
}
