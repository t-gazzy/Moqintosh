//
//  VideoFrameDecoder.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import Foundation

public protocol VideoFrameDecoder: AnyObject, Sendable {
    func decode(_ packet: VideoEncodedPacket) async throws -> VideoFrame
    func finish() async throws
}
