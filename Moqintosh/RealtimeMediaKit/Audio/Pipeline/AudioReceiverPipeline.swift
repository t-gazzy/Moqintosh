//
//  AudioReceiverPipeline.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

final class AudioReceiverPipeline {
    let decoder: OpusAudioDecoder
    let sink: SharedAudioSink

    init(
        decoder: OpusAudioDecoder,
        sink: SharedAudioSink
    ) {
        self.decoder = decoder
        self.sink = sink
    }
}
