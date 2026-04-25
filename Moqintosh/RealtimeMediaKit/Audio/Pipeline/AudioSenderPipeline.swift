//
//  AudioSenderPipeline.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

final class AudioSenderPipeline {
    let source: SharedAudioSource
    let encoder: OpusAudioEncoder
    let sink: AudioEncodedPacketSendingHandler

    init(
        source: SharedAudioSource,
        encoder: OpusAudioEncoder,
        sink: AudioEncodedPacketSendingHandler
    ) {
        self.source = source
        self.encoder = encoder
        self.sink = sink
    }
}
