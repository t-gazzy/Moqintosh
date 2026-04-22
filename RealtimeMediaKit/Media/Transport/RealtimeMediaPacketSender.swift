//
//  RealtimeMediaPacketSender.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

public protocol RealtimeMediaPacketSender: Sendable {
    func send(_ packet: TimedMediaPacket) async throws
}
