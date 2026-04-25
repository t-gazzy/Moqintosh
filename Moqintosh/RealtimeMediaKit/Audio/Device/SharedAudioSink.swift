//
//  SharedAudioSink.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

final class SharedAudioSink: AudioFrameSink {
    private let sharedAudioDevice: SharedAudioDevice
    private let format: AudioFormat
    private var playbackBuffer: AudioPlaybackBuffer?

    init(sharedAudioDevice: SharedAudioDevice, format: AudioFormat) {
        self.sharedAudioDevice = sharedAudioDevice
        self.format = format
    }

    func start() throws {
        self.playbackBuffer = try sharedAudioDevice.acquirePlaybackBuffer(format: format)
    }

    func stop() {
        sharedAudioDevice.releasePlayback()
        self.playbackBuffer = nil
    }

    func handleDecodedFrame(_ frame: AudioFrame) {
        guard let playbackBuffer: AudioPlaybackBuffer = playbackBuffer else {
            OSLogger.debug("Dropped decoded audio frame because the shared audio sink is not active.")
            return
        }
        playbackBuffer.handleDecodedFrame(frame)
    }
}
