//
//  SharedAudioSource.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

final class SharedAudioSource {
    let sharedAudioDevice: SharedAudioDevice
    let format: AudioFormat

    init(sharedAudioDevice: SharedAudioDevice, format: AudioFormat) {
        self.sharedAudioDevice = sharedAudioDevice
        self.format = format
    }

    func start(
        encoder: any AudioFrameEncoder,
        sink: any AudioEncodedPacketSink,
        errorHandler: @escaping @Sendable (Error) -> Void
    ) throws {
        try sharedAudioDevice.startCapture(
            format: format,
            encoder: encoder,
            sink: sink,
            errorHandler: errorHandler
        )
    }

    func stop(sink: any AudioEncodedPacketSink) {
        sharedAudioDevice.stopCapture(sink: sink)
    }
}
