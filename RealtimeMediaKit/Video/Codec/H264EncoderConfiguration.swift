//
//  H264EncoderConfiguration.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import Foundation

public struct H264EncoderConfiguration: Sendable {
    public let inputFormat: VideoFormat
    public let bitrate: Int?
    public let keyFrameInterval: Int

    public init(inputFormat: VideoFormat, bitrate: Int? = nil, keyFrameInterval: Int = 60) {
        precondition(keyFrameInterval > 0, "H264 key frame interval must be greater than zero.")

        self.inputFormat = inputFormat
        self.bitrate = bitrate
        self.keyFrameInterval = keyFrameInterval
    }
}
