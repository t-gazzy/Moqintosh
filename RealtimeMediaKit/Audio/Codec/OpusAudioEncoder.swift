//
//  OpusAudioEncoder.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

public final class OpusAudioEncoder: AudioFrameEncoder {
    private let implementation: any InternalAudioFrameEncoding

    public init(configuration: OpusEncoderConfiguration) throws {
        self.implementation = try AudioFrameEncoderFactory.makeOpusEncoder(configuration: configuration)
    }

    public func encode(_ frame: AudioFrame) throws -> AudioEncodedPacket {
        try implementation.encode(frame)
    }
}
