//
//  VideoReceiver.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

public final class VideoReceiver {
    private let packetReceiver: any RealtimeMediaPacketReceiver
    private let pipeline: VideoReceiverPipeline
    private let errorHandler: @Sendable (Error) -> Void
    private var receivingHandler: VideoEncodedPacketReceivingHandler?

    public init(
        packetReceiver: any RealtimeMediaPacketReceiver,
        sink: any VideoFrameSink,
        errorHandler: @escaping @Sendable (Error) -> Void = { _ in }
    ) {
        self.packetReceiver = packetReceiver
        self.pipeline = VideoReceiverPipeline(
            decoder: H264VideoDecoder(),
            sink: sink
        )
        self.errorHandler = errorHandler
        self.receivingHandler = nil
    }

    deinit {
        receivingHandler?.finish()
    }

    public func start() async throws {
        guard receivingHandler == nil else {
            throw VideoDeviceError.alreadyRunning
        }
        self.receivingHandler = VideoEncodedPacketReceivingHandler(
            receiver: packetReceiver,
            decoder: pipeline.decoder,
            sink: pipeline.sink,
            errorHandler: errorHandler
        )
    }

    public func stop() async {
        receivingHandler?.finish()
        receivingHandler = nil
    }
}
