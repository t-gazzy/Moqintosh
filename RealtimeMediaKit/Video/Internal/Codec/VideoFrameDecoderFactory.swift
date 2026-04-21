//
//  VideoFrameDecoderFactory.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import Foundation

enum VideoFrameDecoderFactory {
    static func makeH264Decoder() -> any InternalVideoFrameDecoding {
        VideoToolboxH264Decoder()
    }
}
