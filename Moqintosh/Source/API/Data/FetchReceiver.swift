//
//  FetchReceiver.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

// Safe because receive() is intended for app-owned consumption.
/// Receives subgroup objects from an accepted fetch stream.
public final class FetchReceiver: @unchecked Sendable {

    /// The accepted fetch subscription associated with this receiver.
    public let fetchSubscription: FetchSubscription

    private let stream: TransportUniReceiveStream
    private let frameReader: FetchObjectFrameReader

    init(stream: TransportUniReceiveStream, fetchSubscription: FetchSubscription, initialData: Data) {
        self.stream = stream
        self.fetchSubscription = fetchSubscription
        self.frameReader = FetchObjectFrameReader(initialData: initialData)
    }

    /// Waits for the next fetch object, or returns nil when the stream closes.
    public func receive() async throws -> SubgroupObject? {
        do {
            return try await frameReader.read(from: stream)
        } catch StreamReceiveCompletionError.closed {
            return nil
        } catch {
            OSLogger.debug("Fetch receive failed: \(error)")
            throw error
        }
    }
}
