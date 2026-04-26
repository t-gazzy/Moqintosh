//
//  AudioReceiverPipeline.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

final class AudioReceiverPipeline {
    let source: any RealtimeMediaPacketReceiver
    let decoder: OpusAudioDecoder
    let sink: SharedAudioSink
    let events: AsyncStream<RealtimeMediaLifecycleEvent>

    private let outputFormat: AudioFormat
    private let eventContinuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation
    private var receivingHandler: AudioEncodedPacketReceivingHandler?

    init(
        packetReceiver: any RealtimeMediaPacketReceiver,
        outputFormat: AudioFormat,
        sharedAudioDevice: SharedAudioDevice
    ) throws {
        let eventStream: (
            stream: AsyncStream<RealtimeMediaLifecycleEvent>,
            continuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation
        ) = makeRealtimeMediaLifecycleEventStream()
        self.source = packetReceiver
        self.decoder = try OpusAudioDecoder(outputFormat: outputFormat)
        self.sink = SharedAudioSink(sharedAudioDevice: sharedAudioDevice, format: outputFormat)
        self.events = eventStream.stream
        self.outputFormat = outputFormat
        self.eventContinuation = eventStream.continuation
        self.receivingHandler = nil
    }

    deinit {
        receivingHandler?.finish()
        sink.stop()
        eventContinuation.finish()
    }

    func start() throws {
        guard receivingHandler == nil else {
            throw AudioDeviceError.alreadyRunning
        }
        do {
            try sink.start()
            receivingHandler = AudioEncodedPacketReceivingHandler(
                receiver: source,
                decoder: decoder,
                outputFormat: outputFormat,
                sink: sink,
                errorHandler: { [eventContinuation] error in
                    eventContinuation.yield(.didFail(error))
                }
            )
            eventContinuation.yield(.didStart)
        } catch {
            sink.stop()
            throw error
        }
    }

    func stop() {
        receivingHandler?.finish()
        receivingHandler = nil
        sink.stop()
        eventContinuation.yield(.didStop)
    }
}
