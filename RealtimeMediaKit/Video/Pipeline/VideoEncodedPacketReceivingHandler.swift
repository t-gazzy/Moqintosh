//
//  VideoEncodedPacketReceivingHandler.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

// Safe because receive loop state is owned by RealtimeMediaReceivingHandler and sink access is synchronized.
final class VideoEncodedPacketReceivingHandler: @unchecked Sendable {
    private let receivingHandler: RealtimeMediaReceivingHandler
    private let sinkStore: VideoFrameSinkStore

    init(
        receiver: any RealtimeMediaPacketReceiver,
        decoder: any VideoFrameDecoder,
        sink: (any VideoFrameSink)? = nil,
        errorHandler: @escaping @Sendable (Error) -> Void = { _ in }
    ) {
        let sinkStore: VideoFrameSinkStore = VideoFrameSinkStore(sink: sink)
        self.sinkStore = sinkStore
        self.receivingHandler = RealtimeMediaReceivingHandler(
            receiver: receiver,
            packetHandler: { packet in
                guard let sink: any VideoFrameSink = sinkStore.sink() else {
                    OSLogger.debug("Dropped video media packet because no video frame sink is attached.")
                    return
                }

                let encodedPacket: VideoEncodedPacket = try VideoEncodedPacketPayloadCodec.decode(packet)
                let decodedFrame: VideoFrame = try await decoder.decode(encodedPacket)
                try await sink.handleDecodedFrame(decodedFrame)
            },
            errorHandler: errorHandler
        )
    }

    init(receivingHandler: RealtimeMediaReceivingHandler) {
        self.receivingHandler = receivingHandler
        self.sinkStore = VideoFrameSinkStore(sink: nil)
    }

    func attachSink(_ sink: any VideoFrameSink) {
        sinkStore.attach(sink)
    }

    func detachSink() {
        sinkStore.detach()
    }

    func finish() {
        receivingHandler.finish()
    }
}
