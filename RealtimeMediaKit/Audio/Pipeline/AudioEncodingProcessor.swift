//
//  AudioEncodingProcessor.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

// Safe because encoder and sink lifetimes are externally managed and not mutated on the realtime path.
public final class AudioEncodingProcessor: @unchecked Sendable, AudioProcessor {
    private let encoder: any AudioFrameEncoder
    private weak var sink: (any AudioEncodedPacketSink)?
    private let errorHandler: @Sendable (Error) -> Void

    public init(
        encoder: any AudioFrameEncoder,
        sink: any AudioEncodedPacketSink,
        errorHandler: @escaping @Sendable (Error) -> Void = { _ in }
    ) {
        self.encoder = encoder
        self.sink = sink
        self.errorHandler = errorHandler
    }

    public func processCapture(_ frame: inout AudioFrame) {
        guard let sink else {
            OSLogger.warn("Dropped captured audio frame because no encoded packet sink is attached.")
            return
        }

        do {
            let packet: AudioEncodedPacket = try encoder.encode(frame)
            sink.handleEncodedPacket(packet)
        } catch {
            OSLogger.error("Failed to encode captured audio frame: \(String(describing: error))")
            errorHandler(error)
        }
    }
}
