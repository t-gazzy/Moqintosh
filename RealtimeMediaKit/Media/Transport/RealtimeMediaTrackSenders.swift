//
//  RealtimeMediaTrackSenders.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

struct RealtimeMediaTrackSenders: Sendable {
    let audio: any RealtimeMediaPacketSender
    let video: any RealtimeMediaPacketSender

    init(audio: any RealtimeMediaPacketSender, video: any RealtimeMediaPacketSender) {
        self.audio = audio
        self.video = video
    }

    func makeAudioSendingHandler(
        initialSequenceNumber: UInt64 = 0,
        initialTimestamp: Int64 = 0,
        bufferingPolicy: AsyncStream<TimedMediaPacket>.Continuation.BufferingPolicy = .bufferingNewest(256),
        errorHandler: @escaping @Sendable (Error) -> Void = { _ in }
    ) -> AudioEncodedPacketSendingHandler {
        AudioEncodedPacketSendingHandler(
            sender: audio,
            initialSequenceNumber: initialSequenceNumber,
            initialTimestamp: initialTimestamp,
            bufferingPolicy: bufferingPolicy,
            errorHandler: errorHandler
        )
    }

    func makeVideoSendingHandler(
        initialSequenceNumber: UInt64 = 0,
        bufferingPolicy: AsyncStream<TimedMediaPacket>.Continuation.BufferingPolicy = .bufferingNewest(256),
        errorHandler: @escaping @Sendable (Error) -> Void = { _ in }
    ) -> VideoEncodedPacketSendingHandler {
        VideoEncodedPacketSendingHandler(
            sender: video,
            initialSequenceNumber: initialSequenceNumber,
            bufferingPolicy: bufferingPolicy,
            errorHandler: errorHandler
        )
    }
}
