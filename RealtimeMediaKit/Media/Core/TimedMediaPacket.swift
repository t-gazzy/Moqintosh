//
//  TimedMediaPacket.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import Foundation

public struct TimedMediaPacket: Sendable, Equatable {
    public let sequenceNumber: UInt64
    public let timestamp: Int64
    public let duration: Int64
    public let payload: Data

    public init(sequenceNumber: UInt64, timestamp: Int64, duration: Int64, payload: Data) {
        self.sequenceNumber = sequenceNumber
        self.timestamp = timestamp
        self.duration = duration
        self.payload = payload
    }
}
