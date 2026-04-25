//
//  AudioSender.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

public final class AudioSender {
    private let pipeline: AudioSenderPipeline
    private let errorHandler: @Sendable (Error) -> Void
    private var isRunning: Bool

    public init(
        packetSender: any RealtimeMediaPacketSender,
        format: AudioFormat,
        sharedAudioDevice: SharedAudioDevice = .shared,
        frameCountPerPacket: Int = 960,
        bitrate: Int = 32_000,
        errorHandler: @escaping @Sendable (Error) -> Void = { _ in }
    ) throws {
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
            errorHandler: errorHandler
        )

        self.pipeline = AudioSenderPipeline(source: source, encoder: encoder, sink: sink)
        self.errorHandler = errorHandler
        self.isRunning = false
    }

    deinit {
        pipeline.source.stop(sink: pipeline.sink)
        pipeline.sink.finish()
    }

    public func start() async throws {
        guard !isRunning else {
            throw AudioDeviceError.alreadyRunning
        }
        do {
            try pipeline.source.start(
                encoder: pipeline.encoder,
                sink: pipeline.sink,
                errorHandler: errorHandler
            )
            isRunning = true
        } catch {
            errorHandler(error)
            throw error
        }
    }

    public func stop() async {
        guard isRunning else {
            return
        }
        pipeline.source.stop(sink: pipeline.sink)
        isRunning = false
    }
}
