//
//  RealtimeMediaPacketReceiver.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

public protocol RealtimeMediaPacketReceiver: Sendable {
    func receive() async throws -> TimedMediaPacket?
}
