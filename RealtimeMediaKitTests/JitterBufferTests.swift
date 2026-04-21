//
//  JitterBufferTests.swift
//  RealtimeMediaKitTests
//
//  Created by Codex on 2026/04/21.
//

import Foundation
import Testing
@testable import RealtimeMediaKit

struct JitterBufferTests {
    private let configuration: JitterBufferConfiguration
    private let clock: ContinuousClock

    init() {
        self.configuration = JitterBufferConfiguration(
            playoutDelay: .milliseconds(50),
            maxPacketCount: 16
        )
        self.clock = ContinuousClock()
    }

    @Test func popsPacketsInSequenceOrder() {
        let buffer: JitterBuffer = JitterBuffer(configuration: configuration)
        let start: ContinuousClock.Instant = clock.now

        buffer.push(makePacket(sequenceNumber: 1), receivedAt: start)
        buffer.push(makePacket(sequenceNumber: 2), receivedAt: start)

        #expect(buffer.popReady(now: start + .milliseconds(50))?.sequenceNumber == 1)
        #expect(buffer.popReady(now: start + .milliseconds(50))?.sequenceNumber == 2)
        #expect(buffer.popReady(now: start + .milliseconds(50)) == nil)
    }

    @Test func reordersOutOfOrderPackets() {
        let buffer: JitterBuffer = JitterBuffer(configuration: configuration)
        let start: ContinuousClock.Instant = clock.now

        buffer.push(makePacket(sequenceNumber: 2), receivedAt: start)
        buffer.push(makePacket(sequenceNumber: 1), receivedAt: start)

        #expect(buffer.popReady(now: start + .milliseconds(50))?.sequenceNumber == 1)
        #expect(buffer.popReady(now: start + .milliseconds(50))?.sequenceNumber == 2)
    }

    @Test func waitsForPlayoutDelayBeforePopping() {
        let buffer: JitterBuffer = JitterBuffer(configuration: configuration)
        let start: ContinuousClock.Instant = clock.now

        buffer.push(makePacket(sequenceNumber: 1), receivedAt: start)

        #expect(buffer.popReady(now: start + .milliseconds(49)) == nil)
        #expect(buffer.popReady(now: start + .milliseconds(50))?.sequenceNumber == 1)
    }

    @Test func skipsMissingSequenceAfterNextPacketIsReady() {
        let buffer: JitterBuffer = JitterBuffer(configuration: configuration)
        let start: ContinuousClock.Instant = clock.now

        buffer.push(makePacket(sequenceNumber: 1), receivedAt: start)
        buffer.push(makePacket(sequenceNumber: 3), receivedAt: start)

        #expect(buffer.popReady(now: start + .milliseconds(50))?.sequenceNumber == 1)
        #expect(buffer.popReady(now: start + .milliseconds(50))?.sequenceNumber == 3)
        #expect(buffer.popReady(now: start + .milliseconds(50)) == nil)
    }

    @Test func dropsDuplicatePackets() {
        let buffer: JitterBuffer = JitterBuffer(configuration: configuration)
        let start: ContinuousClock.Instant = clock.now

        buffer.push(makePacket(sequenceNumber: 1, payload: Data([1])), receivedAt: start)
        buffer.push(makePacket(sequenceNumber: 1, payload: Data([2])), receivedAt: start)

        let packet: TimedMediaPacket? = buffer.popReady(now: start + .milliseconds(50))
        #expect(packet?.sequenceNumber == 1)
        #expect(packet?.payload == Data([1]))
        #expect(buffer.popReady(now: start + .milliseconds(50)) == nil)
    }

    private func makePacket(sequenceNumber: UInt64, payload: Data = Data()) -> TimedMediaPacket {
        TimedMediaPacket(
            sequenceNumber: sequenceNumber,
            timestamp: Int64(sequenceNumber * 1_000),
            duration: 1_000,
            payload: payload
        )
    }
}
