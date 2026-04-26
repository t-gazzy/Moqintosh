//
//  AudioProcessor.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

protocol AudioProcessor: Sendable {
    func processCapture(_ frame: inout AudioFrame)
    func processRender(_ frame: inout AudioFrame)
}

extension AudioProcessor {
    func processCapture(_ frame: inout AudioFrame) {}

    func processRender(_ frame: inout AudioFrame) {}
}
