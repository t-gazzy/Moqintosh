//
//  StreamReceiver.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Receives subgroup objects for a subscribed track.
public actor StreamReceiver {

    /// The subgroup header associated with this receive stream.
    public nonisolated let header: SubgroupHeader

    private let stream: TransportUniReceiveStream
    private let frameReader: SubgroupObjectFrameReader

    init(stream: TransportUniReceiveStream, subscription: Subscription, header: SubgroupHeader, initialData: Data) {
        self.stream = stream
        self.header = header
        self.frameReader = SubgroupObjectFrameReader(header: header, initialData: initialData)
    }

    /// Waits for the next subgroup object, or returns nil when the stream closes.
    public func receive() async throws -> SubgroupObject? {
        do {
            return try await frameReader.read(from: stream)
        } catch StreamReceiveCompletionError.closed {
            return nil
        } catch {
            OSLogger.debug("Stream receive failed: \(error)")
            throw error
        }
    }
}
