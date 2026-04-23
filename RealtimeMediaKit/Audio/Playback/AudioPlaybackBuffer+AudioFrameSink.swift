//
//  AudioPlaybackBuffer+AudioFrameSink.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

extension AudioPlaybackBuffer: AudioFrameSink {
    public func handleDecodedFrame(_ frame: AudioFrame) {
        append(frame)
    }
}
