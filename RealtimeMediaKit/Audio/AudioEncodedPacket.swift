//
//  AudioEncodedPacket.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

public struct AudioEncodedPacket: Sendable {
    public let payload: Data
    public let frameCount: Int
    public let sourceFormat: AudioFormat

    public init(payload: Data, frameCount: Int, sourceFormat: AudioFormat) {
        self.payload = payload
        self.frameCount = frameCount
        self.sourceFormat = sourceFormat
    }
}
