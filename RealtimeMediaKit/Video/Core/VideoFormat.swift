//
//  VideoFormat.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import Foundation

public struct VideoFormat: Sendable, Equatable {
    public let width: Int
    public let height: Int
    public let framesPerSecond: Int

    public init(width: Int, height: Int, framesPerSecond: Int) {
        precondition(width > 0, "Video width must be greater than zero.")
        precondition(height > 0, "Video height must be greater than zero.")
        precondition(framesPerSecond > 0, "Video frame rate must be greater than zero.")

        self.width = width
        self.height = height
        self.framesPerSecond = framesPerSecond
    }
}
