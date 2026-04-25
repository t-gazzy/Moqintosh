//
//  AudioReceiver.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

public final class AudioReceiver {
    private let packetReceiver: any RealtimeMediaPacketReceiver
    private let pipeline: AudioReceiverPipeline
    private let outputFormat: AudioFormat
    private let errorHandler: @Sendable (Error) -> Void
    private var receivingHandler: AudioEncodedPacketReceivingHandler?

    public init(
        packetReceiver: any RealtimeMediaPacketReceiver,
        outputFormat: AudioFormat,
        sharedAudioDevice: SharedAudioDevice = .shared,
        errorHandler: @escaping @Sendable (Error) -> Void = { _ in }
    ) throws {
        let decoder: OpusAudioDecoder = try OpusAudioDecoder(outputFormat: outputFormat)
        let sink: SharedAudioSink = SharedAudioSink(
            sharedAudioDevice: sharedAudioDevice,
            format: outputFormat
        )

        self.packetReceiver = packetReceiver
        self.pipeline = AudioReceiverPipeline(decoder: decoder, sink: sink)
        self.outputFormat = outputFormat
        self.errorHandler = errorHandler
        self.receivingHandler = nil
    }

    deinit {
        receivingHandler?.finish()
        pipeline.sink.stop()
    }

    public func start() async throws {
        guard receivingHandler == nil else {
            throw AudioDeviceError.alreadyRunning
        }

        do {
            try pipeline.sink.start()
            self.receivingHandler = AudioEncodedPacketReceivingHandler(
                receiver: packetReceiver,
                decoder: pipeline.decoder,
                outputFormat: outputFormat,
                sink: pipeline.sink,
                errorHandler: errorHandler
            )
        } catch {
            pipeline.sink.stop()
            errorHandler(error)
            throw error
        }
    }

    public func stop() async {
        receivingHandler?.finish()
        receivingHandler = nil
        pipeline.sink.stop()
    }
}
