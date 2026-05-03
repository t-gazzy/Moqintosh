//
//  AudioReceiver.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

public final class AudioReceiver {
    public let events: AsyncStream<RealtimeMediaLifecycleEvent>

    private let pipeline: AudioReceiverPipeline

    public init(
        packetReceiver: any RealtimeMediaPacketReceiver,
        outputFormat: AudioFormat,
        sharedAudioDevice: SharedAudioDevice = .shared
    ) throws {
        let pipeline: AudioReceiverPipeline = try AudioReceiverPipeline(
            packetReceiver: packetReceiver,
            outputFormat: outputFormat,
            sharedAudioDevice: sharedAudioDevice
        )
        self.events = pipeline.events
        self.pipeline = pipeline
    }

    public func start() async throws {
        try pipeline.start()
    }

    public func stop() async {
        pipeline.stop()
    }
}
