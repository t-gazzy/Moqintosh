//
//  AudioFrameEncoderFactory.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

enum AudioFrameEncoderFactory {
    static func makeOpusEncoder(configuration: OpusEncoderConfiguration) throws -> any InternalAudioFrameEncoding {
        try AudioConverterOpusEncoder(configuration: configuration)
    }
}
