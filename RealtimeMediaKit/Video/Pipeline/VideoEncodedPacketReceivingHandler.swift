//
//  VideoEncodedPacketReceivingHandler.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

// Safe because receive loop state is owned by RealtimeMediaReceivingHandler.
public final class VideoEncodedPacketReceivingHandler: @unchecked Sendable {
    private let receivingHandler: RealtimeMediaReceivingHandler

    public init(
        receiver: any RealtimeMediaPacketReceiver,
        decoder: any VideoFrameDecoder,
        sink: any VideoFrameSink,
        errorHandler: @escaping @Sendable (Error) -> Void = { _ in }
    ) {
        self.receivingHandler = RealtimeMediaReceivingHandler(
            receiver: receiver,
            packetHandler: { packet in
                let encodedPacket: VideoEncodedPacket = try VideoEncodedPacketPayloadCodec.decode(packet)
                let decodedFrame: VideoFrame = try await decoder.decode(encodedPacket)
                try await sink.handleDecodedFrame(decodedFrame)
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
