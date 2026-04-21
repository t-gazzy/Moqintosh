//
//  VideoSource.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import Foundation

public protocol VideoSource: AnyObject {
    var frames: AsyncThrowingStream<VideoFrame, Error> { get }

    func start() async throws
    func stop() async throws
}
