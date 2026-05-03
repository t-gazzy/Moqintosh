//
//  H264VideoEncoder.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import Foundation

// Safe because encoder state is owned by the instance and used through async calls.
public final class H264VideoEncoder: @unchecked Sendable, VideoFrameEncoder {
    private let implementation: any InternalVideoFrameEncoding

    public init(configuration: H264EncoderConfiguration) throws {
        self.implementation = try VideoFrameEncoderFactory.makeH264Encoder(configuration: configuration)
    }

    public func encode(_ frame: VideoFrame) async throws -> VideoEncodedPacket {
        try await implementation.encode(frame)
    }

    public func finish() async throws {
        try await implementation.finish()
    }
}
