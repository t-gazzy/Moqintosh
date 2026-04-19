//
//  OpusEncoderConfiguration.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

public struct OpusEncoderConfiguration: Sendable {
    public let inputFormat: AudioFormat
    public let frameCountPerPacket: Int
    public let bitrate: Int?

    public init(inputFormat: AudioFormat, frameCountPerPacket: Int, bitrate: Int? = nil) {
        self.inputFormat = inputFormat
        self.frameCountPerPacket = frameCountPerPacket
        self.bitrate = bitrate
    }
}
