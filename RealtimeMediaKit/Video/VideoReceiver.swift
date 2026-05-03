//
//  VideoReceiver.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

public final class VideoReceiver {
    public let events: AsyncStream<RealtimeMediaLifecycleEvent>

    private let pipeline: VideoReceiverPipeline

    public init(
        packetReceiver: any RealtimeMediaPacketReceiver,
        sink: any VideoFrameSink
    ) {
        let pipeline: VideoReceiverPipeline = VideoReceiverPipeline(
            packetReceiver: packetReceiver,
            sink: sink
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
