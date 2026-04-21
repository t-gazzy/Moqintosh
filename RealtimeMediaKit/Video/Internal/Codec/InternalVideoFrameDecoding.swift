//
//  InternalVideoFrameDecoding.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import Foundation

protocol InternalVideoFrameDecoding: AnyObject {
    func decode(_ packet: VideoEncodedPacket) async throws -> VideoFrame
    func finish() async throws
}
