//
//  JitterBuffer.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import Foundation
import Synchronization

// Safe because all mutable packet ordering state is protected by state.
public final class JitterBuffer: @unchecked Sendable {
    private let configuration: JitterBufferConfiguration
    private let state: Mutex<State>

    public init(configuration: JitterBufferConfiguration) {
        self.configuration = configuration
        self.state = Mutex<State>(State())
    }

    public func push(_ packet: TimedMediaPacket, receivedAt: ContinuousClock.Instant) {
        state.withLock { state in
            if let expectedSequenceNumber: UInt64 = state.expectedSequenceNumber,
               packet.sequenceNumber < expectedSequenceNumber {
                return
            }

            guard state.packetsBySequenceNumber[packet.sequenceNumber] == nil else {
                return
            }

            let bufferedPacket: BufferedPacket = BufferedPacket(
                packet: packet,
                readyAt: receivedAt + configuration.playoutDelay
            )
            state.packetsBySequenceNumber[packet.sequenceNumber] = bufferedPacket
            trimOverflow(state: &state)
        }
    }

    public func popReady(now: ContinuousClock.Instant) -> TimedMediaPacket? {
        state.withLock { state in
            if state.expectedSequenceNumber == nil {
                state.expectedSequenceNumber = state.packetsBySequenceNumber.keys.min()
            }

            guard let expectedSequenceNumber: UInt64 = state.expectedSequenceNumber else {
                return nil
            }

            if let bufferedPacket: BufferedPacket = state.packetsBySequenceNumber[expectedSequenceNumber] {
                guard bufferedPacket.readyAt <= now else {
                    return nil
                }

                state.packetsBySequenceNumber.removeValue(forKey: expectedSequenceNumber)
                state.expectedSequenceNumber = expectedSequenceNumber + 1
                return bufferedPacket.packet
            }

            guard let nextSequenceNumber: UInt64 = state.packetsBySequenceNumber.keys.min(),
                  nextSequenceNumber > expectedSequenceNumber,
                  let bufferedPacket: BufferedPacket = state.packetsBySequenceNumber[nextSequenceNumber],
                  bufferedPacket.readyAt <= now else {
                return nil
            }

            state.packetsBySequenceNumber.removeValue(forKey: nextSequenceNumber)
            state.expectedSequenceNumber = nextSequenceNumber + 1
            return bufferedPacket.packet
        }
    }

    public func reset() {
        state.withLock { state in
            state = State()
        }
    }
}

extension JitterBuffer {
    private struct BufferedPacket {
        let packet: TimedMediaPacket
        let readyAt: ContinuousClock.Instant
    }

    private struct State {
        var packetsBySequenceNumber: [UInt64: BufferedPacket]
        var expectedSequenceNumber: UInt64?

        init() {
            self.packetsBySequenceNumber = [:]
            self.expectedSequenceNumber = nil
        }
    }

    private func trimOverflow(state: inout State) {
        while state.packetsBySequenceNumber.count > configuration.maxPacketCount {
            guard let sequenceNumber: UInt64 = state.packetsBySequenceNumber.keys.min() else {
                return
            }

            state.packetsBySequenceNumber.removeValue(forKey: sequenceNumber)
            if let expectedSequenceNumber: UInt64 = state.expectedSequenceNumber,
               sequenceNumber == expectedSequenceNumber {
                state.expectedSequenceNumber = state.packetsBySequenceNumber.keys.min()
            }
        }
    }
}
