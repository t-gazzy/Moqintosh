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
        self.implementation = try AudioPacketDecoderFactory.makeOpusDecoder(
            configuration: OpusDecoderConfiguration(outputFormat: outputFormat, frameCountPerPacket: 960)
        )
    }

    public init(configuration: OpusDecoderConfiguration) throws {
        self.implementation = try AudioPacketDecoderFactory.makeOpusDecoder(configuration: configuration)
    }

    public func decode(_ packet: AudioEncodedPacket) throws -> AudioFrame {
        try implementation.decode(packet)
    }
}
