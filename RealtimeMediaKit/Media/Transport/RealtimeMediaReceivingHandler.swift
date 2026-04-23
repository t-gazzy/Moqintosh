//
//  RealtimeMediaReceivingHandler.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

// Safe because the receive task owns packet consumption and lifecycle is controlled by finish/deinit.
public final class RealtimeMediaReceivingHandler: @unchecked Sendable {
    private let receiveTask: Task<Void, Never>

    public init(
        receiver: any RealtimeMediaPacketReceiver,
        packetHandler: @escaping @Sendable (TimedMediaPacket) async throws -> Void,
        errorHandler: @escaping @Sendable (Error) -> Void = { _ in }
    ) {
        self.receiveTask = Task<Void, Never> {
            do {
                while !Task.isCancelled {
                    guard let packet: TimedMediaPacket = try await receiver.receive() else {
                        return
                    }
                    try await packetHandler(packet)
                }
            } catch {
                OSLogger.error("Failed to receive realtime media packet: \(String(describing: error))")
                errorHandler(error)
            }
        }
    }

    deinit {
        receiveTask.cancel()
    }

    public func finish() {
        receiveTask.cancel()
    }
}
