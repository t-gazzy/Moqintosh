//
//  VideoFrame.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import CoreMedia
import CoreVideo
import Foundation

// Safe because VideoFrame only carries an immutable reference to a captured pixel buffer.
public struct VideoFrame: @unchecked Sendable {
    public let pixelBuffer: CVPixelBuffer
    public let presentationTime: CMTime
    public let duration: CMTime

    public init(pixelBuffer: CVPixelBuffer, presentationTime: CMTime, duration: CMTime) {
        self.pixelBuffer = pixelBuffer
        self.presentationTime = presentationTime
        self.duration = duration
    }
}
