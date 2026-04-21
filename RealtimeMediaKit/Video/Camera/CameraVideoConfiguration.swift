//
//  CameraVideoConfiguration.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import Foundation

public struct CameraVideoConfiguration: Sendable {
    public let position: CameraPosition
    public let format: VideoFormat

    public init(position: CameraPosition, format: VideoFormat) {
        self.position = position
        self.format = format
    }
}
