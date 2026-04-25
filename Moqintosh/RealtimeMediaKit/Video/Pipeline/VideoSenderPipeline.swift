//
//  VideoSenderPipeline.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

final class VideoSenderPipeline {
    let capturer: CameraVideoSource
    let encoder: H264VideoEncoder
    let sink: VideoEncodedPacketSendingHandler

    init(
        capturer: CameraVideoSource,
        encoder: H264VideoEncoder,
        sink: VideoEncodedPacketSendingHandler
    ) {
        self.capturer = capturer
        self.encoder = encoder
        self.sink = sink
    }
}
