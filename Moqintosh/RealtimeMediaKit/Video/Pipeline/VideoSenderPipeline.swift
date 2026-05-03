//
//  VideoSenderPipeline.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

final class VideoSenderPipeline {
    let events: AsyncStream<RealtimeMediaLifecycleEvent>

    private let source: CameraVideoSource
    private let encoder: H264VideoEncoder
    private let sink: VideoEncodedPacketSendingHandler
    private let eventContinuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation
    private var sendTask: Task<Void, Never>?

    init(
        packetSender: any RealtimeMediaPacketSender,
        format: VideoFormat,
        cameraPosition: CameraPosition,
        bitrate: Int?,
        keyFrameInterval: Int
    ) throws {
        let eventStream: (
            stream: AsyncStream<RealtimeMediaLifecycleEvent>,
            continuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation
        ) = makeRealtimeMediaLifecycleEventStream()
        self.source = try CameraVideoSource(
            configuration: CameraVideoConfiguration(
                position: cameraPosition,
                format: format
            )
        )
        self.encoder = try H264VideoEncoder(
            configuration: H264EncoderConfiguration(
                inputFormat: format,
                bitrate: bitrate,
                keyFrameInterval: keyFrameInterval
            )
        )
        self.sink = VideoEncodedPacketSendingHandler(
            sender: packetSender,
            errorHandler: { error in
                eventStream.continuation.yield(.didFail(error))
            }
        )
        self.events = eventStream.stream
        self.eventContinuation = eventStream.continuation
        self.sendTask = nil
    }

    deinit {
        sendTask?.cancel()
        sink.finish()
        eventContinuation.finish()
    }

    func start() async throws {
        guard sendTask == nil else {
            throw VideoDeviceError.alreadyRunning
        }

        try await source.start()
        let source: CameraVideoSource = self.source
        let encoder: H264VideoEncoder = self.encoder
        let sink: VideoEncodedPacketSendingHandler = self.sink
        let eventContinuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation = self.eventContinuation

        self.sendTask = Task<Void, Never> {
            do {
                for try await frame in source.frames {
                    let packet: VideoEncodedPacket = try await encoder.encode(frame)
                    sink.handleEncodedPacket(packet)
                }
            } catch {
                eventContinuation.yield(.didFail(error))
            }
        }
        eventContinuation.yield(.didStart)
    }

    func stop() async throws {
        sendTask?.cancel()
        sendTask = nil
        do {
            try await source.stop()
        } catch VideoDeviceError.notRunning {
        }
        eventContinuation.yield(.didStop)
    }
}
