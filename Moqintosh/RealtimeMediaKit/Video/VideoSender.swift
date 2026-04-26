//
//  VideoSender.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

public final class VideoSender {
    public let events: AsyncStream<RealtimeMediaLifecycleEvent>

    private let pipeline: VideoSenderPipeline

    public init(
        packetSender: any RealtimeMediaPacketSender,
        format: VideoFormat,
        cameraPosition: CameraPosition = .front,
        bitrate: Int? = 500_000,
        keyFrameInterval: Int = 30
    ) throws {
        let pipeline: VideoSenderPipeline = try VideoSenderPipeline(
            packetSender: packetSender,
            format: format,
            cameraPosition: cameraPosition,
            bitrate: bitrate,
            keyFrameInterval: keyFrameInterval
        )
        self.events = pipeline.events
        self.pipeline = pipeline
    }

    public func start() async throws {
        try await pipeline.start()
    }

    public func stop() async throws {
        try await pipeline.stop()
    }
}
