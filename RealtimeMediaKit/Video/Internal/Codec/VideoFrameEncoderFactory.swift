//
//  VideoFrameEncoderFactory.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import Foundation

enum VideoFrameEncoderFactory {
    static func makeH264Encoder(configuration: H264EncoderConfiguration) throws -> any InternalVideoFrameEncoding {
        try VideoToolboxH264Encoder(configuration: configuration)
    }
}
