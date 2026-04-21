//
//  OpusDecoderConfiguration.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

public struct OpusDecoderConfiguration: Sendable {
    public let outputFormat: AudioFormat
    public let frameCountPerPacket: Int
    public let magicCookie: Data?

    public init(outputFormat: AudioFormat, frameCountPerPacket: Int, magicCookie: Data? = nil) {
        self.outputFormat = outputFormat
        self.frameCountPerPacket = frameCountPerPacket
        self.magicCookie = magicCookie
    }
}
