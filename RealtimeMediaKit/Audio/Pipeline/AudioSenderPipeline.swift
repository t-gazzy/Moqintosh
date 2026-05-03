//
//  AudioSenderPipeline.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

final class AudioSenderPipeline {
    let events: AsyncStream<RealtimeMediaLifecycleEvent>

    private let sharedAudioDevice: SharedAudioDevice
    private let format: AudioFormat
    private let encoder: OpusAudioEncoder
    private let sink: AudioEncodedPacketSendingHandler
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
        let eventContinuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation = eventStream.continuation
        self.sharedAudioDevice = sharedAudioDevice
        self.format = format
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
                eventContinuation.yield(.didFail(error))
            }
        )
        self.events = eventStream.stream
        self.eventContinuation = eventContinuation
        self.isRunning = false
    }

    deinit {
        sharedAudioDevice.stopCapture(sink: sink)
        eventContinuation.finish()
    }

    func start() throws {
        guard !isRunning else {
            throw AudioDeviceError.alreadyRunning
        }
        try sharedAudioDevice.startCapture(
            format: format,
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
        sharedAudioDevice.stopCapture(sink: sink)
        isRunning = false
        eventContinuation.yield(.didStop)
    }
}
