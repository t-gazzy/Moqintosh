//
//  AudioFrameSink.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

public protocol AudioFrameSink: AnyObject {
    func handleDecodedFrame(_ frame: AudioFrame)
}
