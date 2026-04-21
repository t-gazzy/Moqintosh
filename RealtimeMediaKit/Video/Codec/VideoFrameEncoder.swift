//
//  VideoFrameEncoder.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import Foundation

public protocol VideoFrameEncoder: AnyObject {
    func encode(_ frame: VideoFrame) async throws -> VideoEncodedPacket
    func finish() async throws
}
