//
//  AudioSenderPipeline.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

final class AudioSenderPipeline {
    let source: SharedAudioSource
    let encoder: OpusAudioEncoder
    let sink: AudioEncodedPacketSendingHandler
    let events: AsyncStream<RealtimeMediaLifecycleEvent>

    private let eventContinuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation
    private var isRunning: Bool

    init(
        packetSender: any RealtimeMediaPacketSender,
        format: AudioFormat,
        sharedAudioDevice: SharedAudioDevice,
        frameCountPerPacket: Int,
        bitrate: Int
    ) throws {
        let eventStream: (
            stream: AsyncStream<RealtimeMediaLifecycleEvent>,
            continuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation
        ) = makeRealtimeMediaLifecycleEventStream()
        self.source = SharedAudioSource(sharedAudioDevice: sharedAudioDevice, format: format)
        self.encoder = try OpusAudioEncoder(
            configuration: OpusEncoderConfiguration(
                inputFormat: format,
                frameCountPerPacket: frameCountPerPacket,
                bitrate: bitrate
            )
        )
        self.sink = AudioEncodedPacketSendingHandler(
            sender: packetSender,
            errorHandler: { error in
                eventStream.continuation.yield(.didFail(error))
            }
        )
        self.events = eventStream.stream
        self.eventContinuation = eventStream.continuation
        self.isRunning = false
    }

    deinit {
        source.stop(sink: sink)
        sink.finish()
        eventContinuation.finish()
    }

    func start() throws {
        guard !isRunning else {
            throw AudioDeviceError.alreadyRunning
        }
        try source.start(
            encoder: encoder,
            sink: sink,
            errorHandler: { [eventContinuation] error in
                eventContinuation.yield(.didFail(error))
            }
        )
        isRunning = true
        eventContinuation.yield(.didStart)
    }

    func stop() {
        guard isRunning else {
            return
        }
        source.stop(sink: sink)
        isRunning = false
        eventContinuation.yield(.didStop)
    }
}
