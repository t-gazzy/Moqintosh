//
//  AudioSender.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

public final class AudioSender {
    public let events: AsyncStream<RealtimeMediaLifecycleEvent>

    private let pipeline: AudioSenderPipeline
    private let eventContinuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation
    private var isRunning: Bool

    public init(
        packetSender: any RealtimeMediaPacketSender,
        format: AudioFormat,
        sharedAudioDevice: SharedAudioDevice = .shared,
        frameCountPerPacket: Int = 960,
        bitrate: Int = 32_000
    ) throws {
        let eventStream: (
            stream: AsyncStream<RealtimeMediaLifecycleEvent>,
            continuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation
        ) = makeRealtimeMediaLifecycleEventStream()
        let source: SharedAudioSource = SharedAudioSource(
            sharedAudioDevice: sharedAudioDevice,
            format: format
        )
        let encoder: OpusAudioEncoder = try OpusAudioEncoder(
            configuration: OpusEncoderConfiguration(
                inputFormat: format,
                frameCountPerPacket: frameCountPerPacket,
                bitrate: bitrate
            )
        )
        let sink: AudioEncodedPacketSendingHandler = AudioEncodedPacketSendingHandler(
            sender: packetSender,
            errorHandler: { error in
                eventStream.continuation.yield(.didFail(error))
            }
        )

        self.events = eventStream.stream
        self.pipeline = AudioSenderPipeline(source: source, encoder: encoder, sink: sink)
        self.eventContinuation = eventStream.continuation
        self.isRunning = false
    }

    deinit {
        pipeline.source.stop(sink: pipeline.sink)
        pipeline.sink.finish()
        eventContinuation.finish()
    }

    public func start() async throws {
        guard !isRunning else {
            throw AudioDeviceError.alreadyRunning
        }
        do {
            try pipeline.source.start(
                encoder: pipeline.encoder,
                sink: pipeline.sink,
                errorHandler: { [eventContinuation] error in
                    eventContinuation.yield(.didFail(error))
                }
            )
            isRunning = true
            eventContinuation.yield(.didStart)
        } catch {
            throw error
        }
    }

    public func stop() async {
        guard isRunning else {
            return
        }
        pipeline.source.stop(sink: pipeline.sink)
        isRunning = false
        eventContinuation.yield(.didStop)
    }
}
