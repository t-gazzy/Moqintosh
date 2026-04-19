//
//  AudioPacketDecoderFactory.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

enum AudioPacketDecoderFactory {
    static func makeOpusDecoder(outputFormat: AudioFormat) throws -> any InternalAudioPacketDecoding {
        try AudioConverterOpusDecoder(outputFormat: outputFormat)
    }
}
