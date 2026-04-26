//
//  VideoReceiver.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

public final class VideoReceiver {
    public let events: AsyncStream<RealtimeMediaLifecycleEvent>

    private let packetReceiver: any RealtimeMediaPacketReceiver
    private let pipeline: VideoReceiverPipeline
    private let eventContinuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation
    private var receivingHandler: VideoEncodedPacketReceivingHandler?

    public init(
        packetReceiver: any RealtimeMediaPacketReceiver,
        sink: any VideoFrameSink
    ) {
        let eventStream: (
            stream: AsyncStream<RealtimeMediaLifecycleEvent>,
            continuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation
        ) = makeRealtimeMediaLifecycleEventStream()
        self.events = eventStream.stream
        self.packetReceiver = packetReceiver
        self.pipeline = VideoReceiverPipeline(
            decoder: H264VideoDecoder(),
            sink: sink
        )
        self.eventContinuation = eventStream.continuation
        self.receivingHandler = nil
    }

    deinit {
        receivingHandler?.finish()
        eventContinuation.finish()
    }

    public func start() async throws {
        guard receivingHandler == nil else {
            throw VideoDeviceError.alreadyRunning
        }
        self.receivingHandler = VideoEncodedPacketReceivingHandler(
            receiver: packetReceiver,
            decoder: pipeline.decoder,
            sink: pipeline.sink,
            errorHandler: { [eventContinuation] error in
                eventContinuation.yield(.didFail(error))
            }
        )
        eventContinuation.yield(.didStart)
    }

    public func stop() async {
        receivingHandler?.finish()
        receivingHandler = nil
        eventContinuation.yield(.didStop)
    }
}
