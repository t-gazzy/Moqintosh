//
//  AudioFormat.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

public struct AudioFormat: Sendable, Equatable {
    public let sampleRate: Double
    public let channelCount: Int
    public let bytesPerSample: Int

    public init(sampleRate: Double, channelCount: Int, bytesPerSample: Int) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.bytesPerSample = bytesPerSample
    }
}
