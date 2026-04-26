//
//  RealtimeMediaSendingHandler.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

public enum RealtimeMediaLifecycleEvent {
    case didStart
    case didStop
    case didFail(any Error)
}

func makeRealtimeMediaLifecycleEventStream() -> (
    stream: AsyncStream<RealtimeMediaLifecycleEvent>,
    continuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation
) {
    var streamContinuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation?
    let stream: AsyncStream<RealtimeMediaLifecycleEvent> = AsyncStream<RealtimeMediaLifecycleEvent> { continuation in
        streamContinuation = continuation
    }
    guard let streamContinuation else {
        preconditionFailure("AsyncStream must create a continuation.")
    }
    return (stream, streamContinuation)
}

// Safe because AsyncStream.Continuation supports concurrent yield and the send loop owns consumption.
public final class RealtimeMediaSendingHandler: @unchecked Sendable {
    private let continuation: AsyncStream<TimedMediaPacket>.Continuation
    private let sendTask: Task<Void, Never>

    public init(
        sender: any RealtimeMediaPacketSender,
        bufferingPolicy: AsyncStream<TimedMediaPacket>.Continuation.BufferingPolicy = .bufferingNewest(256),
        errorHandler: @escaping @Sendable (Error) -> Void = { _ in }
    ) {
        let packetStream: (
            stream: AsyncStream<TimedMediaPacket>,
            continuation: AsyncStream<TimedMediaPacket>.Continuation
        ) = RealtimeMediaSendingHandler.makePacketStream(bufferingPolicy: bufferingPolicy)
        self.continuation = packetStream.continuation
        self.sendTask = Task<Void, Never> {
            for await packet in packetStream.stream {
                do {
                    try await sender.send(packet)
                } catch {
                    OSLogger.error("Failed to send realtime media packet: \(String(describing: error))")
                    errorHandler(error)
                }
            }
        }
    }

    deinit {
        continuation.finish()
        sendTask.cancel()
    }

    public func enqueue(_ packet: TimedMediaPacket) {
        let result: AsyncStream<TimedMediaPacket>.Continuation.YieldResult = continuation.yield(packet)
        switch result {
        case .enqueued:
            break
        case .dropped:
            OSLogger.warn("Dropped realtime media packet because sender buffer is full (sequenceNumber: \(packet.sequenceNumber))")
        case .terminated:
            OSLogger.debug("Dropped realtime media packet because sender is terminated (sequenceNumber: \(packet.sequenceNumber))")
        @unknown default:
            OSLogger.warn("Dropped realtime media packet for an unknown reason (sequenceNumber: \(packet.sequenceNumber))")
        }
    }

    public func finish() {
        continuation.finish()
    }

    private static func makePacketStream(
        bufferingPolicy: AsyncStream<TimedMediaPacket>.Continuation.BufferingPolicy
    ) -> (
        stream: AsyncStream<TimedMediaPacket>,
        continuation: AsyncStream<TimedMediaPacket>.Continuation
    ) {
        var streamContinuation: AsyncStream<TimedMediaPacket>.Continuation?
        let stream: AsyncStream<TimedMediaPacket> = AsyncStream<TimedMediaPacket>(
            bufferingPolicy: bufferingPolicy
        ) { continuation in
            streamContinuation = continuation
        }
        guard let streamContinuation else {
            preconditionFailure("AsyncStream must create a continuation")
        }
        return (stream, streamContinuation)
    }
}
