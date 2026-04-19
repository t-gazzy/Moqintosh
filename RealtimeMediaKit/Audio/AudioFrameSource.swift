//
//  AudioFrameSource.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

public protocol AudioFrameSource: AnyObject {
    func render(into frame: inout AudioFrame)
}
