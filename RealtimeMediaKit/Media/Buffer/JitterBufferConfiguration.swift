//
//  JitterBufferConfiguration.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import Foundation

public struct JitterBufferConfiguration: Sendable, Equatable {
    public let playoutDelay: Duration
    public let maxPacketCount: Int

    public init(playoutDelay: Duration, maxPacketCount: Int) {
        precondition(maxPacketCount > 0, "JitterBuffer maxPacketCount must be greater than zero.")

        self.playoutDelay = playoutDelay
        self.maxPacketCount = maxPacketCount
    }
}
