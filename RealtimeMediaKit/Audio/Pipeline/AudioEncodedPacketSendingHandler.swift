//
//  AudioEncodedPacketSendingHandler.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation
import Synchronization

// Safe because sequence and timestamp state is protected by state.
final class AudioEncodedPacketSendingHandler: @unchecked Sendable, AudioEncodedPacketSink {
    private let sendingHandler: RealtimeMediaSendingHandler
    private let state: Mutex<State>

    init(
        sender: any RealtimeMediaPacketSender,
        initialSequenceNumber: UInt64 = 0,
        initialTimestamp: Int64 = 0,
        bufferingPolicy: AsyncStream<TimedMediaPacket>.Continuation.BufferingPolicy = .bufferingNewest(256),
        errorHandler: @escaping @Sendable (Error) -> Void = { _ in }
    ) {
        self.sendingHandler = RealtimeMediaSendingHandler(
            sender: sender,
            bufferingPolicy: bufferingPolicy,
            errorHandler: errorHandler
        )
        self.state = Mutex<State>(
            State(sequenceNumber: initialSequenceNumber, timestamp: initialTimestamp)
        )
    }

    init(
        sendingHandler: RealtimeMediaSendingHandler,
        initialSequenceNumber: UInt64 = 0,
        initialTimestamp: Int64 = 0
    ) {
        self.sendingHandler = sendingHandler
        self.state = Mutex<State>(
            State(sequenceNumber: initialSequenceNumber, timestamp: initialTimestamp)
        )
    }

    func handleEncodedPacket(_ packet: AudioEncodedPacket) {
        let timedPacket: TimedMediaPacket = state.withLock { state in
            let duration: Int64 = Int64(packet.frameCount)
            let timedPacket: TimedMediaPacket = TimedMediaPacket(
                sequenceNumber: state.sequenceNumber,
                timestamp: state.timestamp,
                duration: duration,
                payload: packet.payload
            )
            state.sequenceNumber += 1
            state.timestamp += duration
            return timedPacket
        }
        sendingHandler.enqueue(timedPacket)
    }
}

extension AudioEncodedPacketSendingHandler {
    private struct State {
        var sequenceNumber: UInt64
        var timestamp: Int64

        init(sequenceNumber: UInt64, timestamp: Int64) {
            self.sequenceNumber = sequenceNumber
            self.timestamp = timestamp
        }
    }
}
