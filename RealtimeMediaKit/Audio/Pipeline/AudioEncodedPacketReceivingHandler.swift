//
//  AudioEncodedPacketReceivingHandler.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

// Safe because receive loop state is owned by RealtimeMediaReceivingHandler and sink access is synchronized.
final class AudioEncodedPacketReceivingHandler: @unchecked Sendable {
    private let receivingHandler: RealtimeMediaReceivingHandler
    private let sinkStore: AudioFrameSinkStore

    init(
        receiver: any RealtimeMediaPacketReceiver,
        decoder: any AudioPacketDecoder,
        outputFormat: AudioFormat,
        sink: (any AudioFrameSink)? = nil,
        errorHandler: @escaping @Sendable (Error) -> Void = { _ in }
    ) {
        let sinkStore: AudioFrameSinkStore = AudioFrameSinkStore(sink: sink)
        self.sinkStore = sinkStore
        self.receivingHandler = RealtimeMediaReceivingHandler(
            receiver: receiver,
            packetHandler: { packet in
                guard let sink: any AudioFrameSink = sinkStore.sink() else {
                    OSLogger.debug("Dropped audio media packet because no audio frame sink is attached.")
                    return
                }

                let encodedPacket: AudioEncodedPacket = AudioEncodedPacket(
                    payload: packet.payload,
                    frameCount: Int(packet.duration),
                    sourceFormat: outputFormat
                )
                let decodedFrame: AudioFrame = try decoder.decode(encodedPacket)
                sink.handleDecodedFrame(decodedFrame)
            },
            errorHandler: errorHandler
        )
    }

    init(receivingHandler: RealtimeMediaReceivingHandler) {
        self.receivingHandler = receivingHandler
        self.sinkStore = AudioFrameSinkStore(sink: nil)
    }

    func attachSink(_ sink: any AudioFrameSink) {
        sinkStore.attach(sink)
    }

    func detachSink() {
        sinkStore.detach()
    }

    func finish() {
        receivingHandler.finish()
    }
}
