//
//  OpusAudioDecoder.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

public final class OpusAudioDecoder: AudioPacketDecoder {
    private let implementation: any InternalAudioPacketDecoding

    public init(outputFormat: AudioFormat) throws {
        self.implementation = try AudioPacketDecoderFactory.makeOpusDecoder(outputFormat: outputFormat)
    }

    public func decode(_ packet: AudioEncodedPacket) throws -> AudioFrame {
        try implementation.decode(packet)
    }
}
