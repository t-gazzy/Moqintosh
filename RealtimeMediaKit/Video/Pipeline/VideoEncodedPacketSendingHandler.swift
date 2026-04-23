//
//  VideoEncodedPacketSendingHandler.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import CoreMedia
import Foundation
import Synchronization

// Safe because sequence state is protected by state.
public final class VideoEncodedPacketSendingHandler: @unchecked Sendable, VideoEncodedPacketSink {
    private let sendingHandler: RealtimeMediaSendingHandler
    private let state: Mutex<State>

    public init(
        sender: any RealtimeMediaPacketSender,
        initialSequenceNumber: UInt64 = 0,
        bufferingPolicy: AsyncStream<TimedMediaPacket>.Continuation.BufferingPolicy = .bufferingNewest(256),
        errorHandler: @escaping @Sendable (Error) -> Void = { _ in }
    ) {
        self.sendingHandler = RealtimeMediaSendingHandler(
            sender: sender,
            bufferingPolicy: bufferingPolicy,
            errorHandler: errorHandler
        )
        self.state = Mutex<State>(State(sequenceNumber: initialSequenceNumber))
    }

    public init(
        sendingHandler: RealtimeMediaSendingHandler,
        initialSequenceNumber: UInt64 = 0
    ) {
        self.sendingHandler = sendingHandler
        self.state = Mutex<State>(State(sequenceNumber: initialSequenceNumber))
    }

    public func handleEncodedPacket(_ packet: VideoEncodedPacket) {
        let payload: Data = VideoEncodedPacketPayloadCodec.encode(packet)
        let sequenceNumber: UInt64 = state.withLock { state in
            let sequenceNumber: UInt64 = state.sequenceNumber
            state.sequenceNumber += 1
            return sequenceNumber
        }
        let timedPacket: TimedMediaPacket = TimedMediaPacket(
            sequenceNumber: sequenceNumber,
            timestamp: packet.presentationTime.value,
            duration: packet.duration.value,
            payload: payload
        )
        sendingHandler.enqueue(timedPacket)
    }
}

extension VideoEncodedPacketSendingHandler {
    private struct State {
        var sequenceNumber: UInt64

        init(sequenceNumber: UInt64) {
            self.sequenceNumber = sequenceNumber
        }
    }
}
