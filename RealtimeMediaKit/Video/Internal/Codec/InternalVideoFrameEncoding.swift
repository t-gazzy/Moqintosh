//
//  InternalVideoFrameEncoding.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import Foundation

protocol InternalVideoFrameEncoding: AnyObject {
    func encode(_ frame: VideoFrame) async throws -> VideoEncodedPacket
    func finish() async throws
}
