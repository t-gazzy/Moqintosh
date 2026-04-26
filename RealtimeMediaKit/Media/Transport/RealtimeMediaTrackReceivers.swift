//
//  RealtimeMediaTrackReceivers.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

struct RealtimeMediaTrackReceivers: Sendable {
    let audio: any RealtimeMediaPacketReceiver
    let video: any RealtimeMediaPacketReceiver

    init(audio: any RealtimeMediaPacketReceiver, video: any RealtimeMediaPacketReceiver) {
        self.audio = audio
        self.video = video
    }

    func makeAudioReceivingHandler(
        decoder: any AudioPacketDecoder,
        outputFormat: AudioFormat,
        sink: (any AudioFrameSink)? = nil,
        errorHandler: @escaping @Sendable (Error) -> Void = { _ in }
    ) -> AudioEncodedPacketReceivingHandler {
        AudioEncodedPacketReceivingHandler(
            receiver: audio,
            decoder: decoder,
            outputFormat: outputFormat,
            sink: sink,
            errorHandler: errorHandler
        )
    }

    func makeVideoReceivingHandler(
        decoder: any VideoFrameDecoder,
        sink: (any VideoFrameSink)? = nil,
        errorHandler: @escaping @Sendable (Error) -> Void = { _ in }
    ) -> VideoEncodedPacketReceivingHandler {
        VideoEncodedPacketReceivingHandler(
            receiver: video,
            decoder: decoder,
            sink: sink,
            errorHandler: errorHandler
        )
    }
}
