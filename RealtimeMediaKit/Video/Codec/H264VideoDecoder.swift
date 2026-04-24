//
//  H264VideoDecoder.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import Foundation

// Safe because decoder state is owned by the instance and used through async calls.
public final class H264VideoDecoder: @unchecked Sendable, VideoFrameDecoder {
    private let implementation: any InternalVideoFrameDecoding

    public init() {
        self.implementation = VideoFrameDecoderFactory.makeH264Decoder()
    }

    public func decode(_ packet: VideoEncodedPacket) async throws -> VideoFrame {
        try await implementation.decode(packet)
    }

    public func finish() async throws {
        try await implementation.finish()
    }
}
