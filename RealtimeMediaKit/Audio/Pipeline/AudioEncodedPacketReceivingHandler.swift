//
//  AudioEncodedPacketReceivingHandler.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

// Safe because receive loop state is owned by RealtimeMediaReceivingHandler.
public final class AudioEncodedPacketReceivingHandler: @unchecked Sendable {
    private let receivingHandler: RealtimeMediaReceivingHandler

    public init(
        receiver: any RealtimeMediaPacketReceiver,
        decoder: any AudioPacketDecoder,
        outputFormat: AudioFormat,
        sink: any AudioFrameSink,
        errorHandler: @escaping @Sendable (Error) -> Void = { _ in }
    ) {
        self.receivingHandler = RealtimeMediaReceivingHandler(
            receiver: receiver,
            packetHandler: { packet in
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

    public init(receivingHandler: RealtimeMediaReceivingHandler) {
        self.receivingHandler = receivingHandler
    }

    public func finish() {
        receivingHandler.finish()
    }
}
