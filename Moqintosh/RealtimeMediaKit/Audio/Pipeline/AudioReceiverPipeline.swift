//
//  AudioReceiverPipeline.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

final class AudioReceiverPipeline {
    let events: AsyncStream<RealtimeMediaLifecycleEvent>

    private let sharedAudioDevice: SharedAudioDevice
    private let source: any RealtimeMediaPacketReceiver
    private let decoder: OpusAudioDecoder
    private let outputFormat: AudioFormat
    private let eventContinuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation
    private var playbackBuffer: AudioPlaybackBuffer?
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
        self.sharedAudioDevice = sharedAudioDevice
        self.source = packetReceiver
        self.decoder = try OpusAudioDecoder(outputFormat: outputFormat)
        self.events = eventStream.stream
        self.outputFormat = outputFormat
        self.eventContinuation = eventStream.continuation
        self.playbackBuffer = nil
        self.receivingHandler = nil
    }

    deinit {
        receivingHandler?.finish()
        stopPlayback()
        eventContinuation.finish()
    }

    func start() throws {
        guard receivingHandler == nil else {
            throw AudioDeviceError.alreadyRunning
        }
        do {
            self.playbackBuffer = try sharedAudioDevice.acquirePlaybackBuffer(format: outputFormat)
            receivingHandler = AudioEncodedPacketReceivingHandler(
                receiver: source,
                decoder: decoder,
                outputFormat: outputFormat,
                sink: self,
                errorHandler: { [eventContinuation] error in
                    eventContinuation.yield(.didFail(error))
                }
            )
            eventContinuation.yield(.didStart)
        } catch {
            stopPlayback()
            throw error
        }
    }

    func stop() {
        receivingHandler?.finish()
        receivingHandler = nil
        stopPlayback()
        eventContinuation.yield(.didStop)
    }

    private func stopPlayback() {
        guard playbackBuffer != nil else {
            return
        }
        sharedAudioDevice.releasePlayback()
        playbackBuffer = nil
    }
}

extension AudioReceiverPipeline: AudioFrameSink {
    func handleDecodedFrame(_ frame: AudioFrame) {
        guard let playbackBuffer: AudioPlaybackBuffer = playbackBuffer else {
            OSLogger.debug("Dropped decoded audio frame because the shared audio sink is not active.")
            return
        }
        playbackBuffer.handleDecodedFrame(frame)
    }
}
