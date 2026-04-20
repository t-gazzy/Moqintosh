//
//  AudioProcessor.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

public protocol AudioProcessor: Sendable {
    func processCapture(_ frame: inout AudioFrame)
    func processRender(_ frame: inout AudioFrame)
}

public extension AudioProcessor {
    func processCapture(_ frame: inout AudioFrame) {}

    func processRender(_ frame: inout AudioFrame) {}
}
