//
//  AudioSender.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

public final class AudioSender {
    public let events: AsyncStream<RealtimeMediaLifecycleEvent>

    private let pipeline: AudioSenderPipeline

    public init(
        packetSender: any RealtimeMediaPacketSender,
        format: AudioFormat,
        sharedAudioDevice: SharedAudioDevice = .shared,
        frameCountPerPacket: Int = 960,
        bitrate: Int = 32_000
    ) throws {
        let pipeline: AudioSenderPipeline = try AudioSenderPipeline(
            packetSender: packetSender,
            format: format,
            sharedAudioDevice: sharedAudioDevice,
            frameCountPerPacket: frameCountPerPacket,
            bitrate: bitrate
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
