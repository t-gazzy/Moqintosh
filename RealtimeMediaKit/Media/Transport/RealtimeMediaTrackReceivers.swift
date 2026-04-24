//
//  RealtimeMediaTrackReceivers.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

public struct RealtimeMediaTrackReceivers: Sendable {
    public let audio: any RealtimeMediaPacketReceiver
    public let video: any RealtimeMediaPacketReceiver

    public init(audio: any RealtimeMediaPacketReceiver, video: any RealtimeMediaPacketReceiver) {
        self.audio = audio
        self.video = video
    }

    public func makeAudioReceivingHandler(
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

    public func makeVideoReceivingHandler(
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
