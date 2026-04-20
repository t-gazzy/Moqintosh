//
//  AudioFrameEncoder.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

public protocol AudioFrameEncoder: AnyObject {
    func encode(_ frame: AudioFrame) throws -> AudioEncodedPacket
}
