//
//  VideoReceiverPipeline.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

final class VideoReceiverPipeline {
    let decoder: H264VideoDecoder
    let sink: any VideoFrameSink

    init(
        decoder: H264VideoDecoder,
        sink: any VideoFrameSink
    ) {
        self.decoder = decoder
        self.sink = sink
    }
}
