//
//  VideoRenderView+VideoFrameSink.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
import Foundation

extension VideoRenderView: VideoFrameSink {
    @MainActor
    public func handleDecodedFrame(_ frame: VideoFrame) async throws {
        try enqueue(frame)
    }
}
#endif
