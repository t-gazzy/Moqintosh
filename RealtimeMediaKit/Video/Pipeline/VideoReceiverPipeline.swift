//
//  VideoReceiverPipeline.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

final class VideoReceiverPipeline {
    let events: AsyncStream<RealtimeMediaLifecycleEvent>

    private let source: any RealtimeMediaPacketReceiver
    private let decoder: H264VideoDecoder
    private let sink: any VideoFrameSink
    private let eventContinuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation
    private var receivingHandler: VideoEncodedPacketReceivingHandler?

    init(
        packetReceiver: any RealtimeMediaPacketReceiver,
        sink: any VideoFrameSink
    ) {
        let eventStream: (
            stream: AsyncStream<RealtimeMediaLifecycleEvent>,
            continuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation
        ) = makeRealtimeMediaLifecycleEventStream()
        self.source = packetReceiver
        self.decoder = H264VideoDecoder()
        self.sink = sink
        self.events = eventStream.stream
        self.eventContinuation = eventStream.continuation
        self.receivingHandler = nil
    }

    deinit {
        receivingHandler?.finish()
        eventContinuation.finish()
    }

    func start() throws {
        guard receivingHandler == nil else {
            throw VideoDeviceError.alreadyRunning
        }
        receivingHandler = VideoEncodedPacketReceivingHandler(
            receiver: source,
            decoder: decoder,
            sink: sink,
            errorHandler: { [eventContinuation] error in
                eventContinuation.yield(.didFail(error))
            }
        )
        eventContinuation.yield(.didStart)
    }

    func stop() {
        receivingHandler?.finish()
        receivingHandler = nil
        eventContinuation.yield(.didStop)
    }
}
