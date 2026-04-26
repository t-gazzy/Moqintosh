//
//  AudioReceiver.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

public final class AudioReceiver {
    public let events: AsyncStream<RealtimeMediaLifecycleEvent>

    private let packetReceiver: any RealtimeMediaPacketReceiver
    private let pipeline: AudioReceiverPipeline
    private let outputFormat: AudioFormat
    private let eventContinuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation
    private var receivingHandler: AudioEncodedPacketReceivingHandler?

    public init(
        packetReceiver: any RealtimeMediaPacketReceiver,
        outputFormat: AudioFormat,
        sharedAudioDevice: SharedAudioDevice = .shared
    ) throws {
        let eventStream: (
            stream: AsyncStream<RealtimeMediaLifecycleEvent>,
            continuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation
        ) = makeRealtimeMediaLifecycleEventStream()
        let decoder: OpusAudioDecoder = try OpusAudioDecoder(outputFormat: outputFormat)
        let sink: SharedAudioSink = SharedAudioSink(
            sharedAudioDevice: sharedAudioDevice,
            format: outputFormat
        )

        self.events = eventStream.stream
        self.packetReceiver = packetReceiver
        self.pipeline = AudioReceiverPipeline(decoder: decoder, sink: sink)
        self.outputFormat = outputFormat
        self.eventContinuation = eventStream.continuation
        self.receivingHandler = nil
    }

    deinit {
        receivingHandler?.finish()
        pipeline.sink.stop()
        eventContinuation.finish()
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
                errorHandler: { [eventContinuation] error in
                    eventContinuation.yield(.didFail(error))
                }
            )
            eventContinuation.yield(.didStart)
        } catch {
            pipeline.sink.stop()
            throw error
        }
    }

    public func stop() async {
        receivingHandler?.finish()
        receivingHandler = nil
        pipeline.sink.stop()
        eventContinuation.yield(.didStop)
    }
}
