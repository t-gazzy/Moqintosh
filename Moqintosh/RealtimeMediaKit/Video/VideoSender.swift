//
//  VideoSender.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

public final class VideoSender {
    public let events: AsyncStream<RealtimeMediaLifecycleEvent>

    private let pipeline: VideoSenderPipeline
    private let eventContinuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation
    private var sendTask: Task<Void, Never>?

    public init(
        packetSender: any RealtimeMediaPacketSender,
        format: VideoFormat,
        cameraPosition: CameraPosition = .front,
        bitrate: Int? = 500_000,
        keyFrameInterval: Int = 30
    ) throws {
        let eventStream: (
            stream: AsyncStream<RealtimeMediaLifecycleEvent>,
            continuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation
        ) = makeRealtimeMediaLifecycleEventStream()
        let capturer: CameraVideoSource = try CameraVideoSource(
            configuration: CameraVideoConfiguration(
                position: cameraPosition,
                format: format
            )
        )
        let encoder: H264VideoEncoder = try H264VideoEncoder(
            configuration: H264EncoderConfiguration(
                inputFormat: format,
                bitrate: bitrate,
                keyFrameInterval: keyFrameInterval
            )
        )
        let sink: VideoEncodedPacketSendingHandler = VideoEncodedPacketSendingHandler(
            sender: packetSender,
            errorHandler: { error in
                eventStream.continuation.yield(.didFail(error))
            }
        )

        self.events = eventStream.stream
        self.pipeline = VideoSenderPipeline(
            capturer: capturer,
            encoder: encoder,
            sink: sink
        )
        self.eventContinuation = eventStream.continuation
        self.sendTask = nil
    }

    deinit {
        sendTask?.cancel()
        pipeline.sink.finish()
        eventContinuation.finish()
    }

    public func start() async throws {
        guard sendTask == nil else {
            throw VideoDeviceError.alreadyRunning
        }

        try await pipeline.capturer.start()
        let capturer: CameraVideoSource = pipeline.capturer
        let encoder: H264VideoEncoder = pipeline.encoder
        let sink: VideoEncodedPacketSendingHandler = pipeline.sink
        let eventContinuation: AsyncStream<RealtimeMediaLifecycleEvent>.Continuation = self.eventContinuation

        self.sendTask = Task<Void, Never> {
            do {
                for try await frame in capturer.frames {
                    let packet: VideoEncodedPacket = try await encoder.encode(frame)
                    sink.handleEncodedPacket(packet)
                }
            } catch {
                eventContinuation.yield(.didFail(error))
            }
        }
        eventContinuation.yield(.didStart)
    }

    public func stop() async throws {
        sendTask?.cancel()
        sendTask = nil
        do {
            try await pipeline.capturer.stop()
        } catch VideoDeviceError.notRunning {
        }
        eventContinuation.yield(.didStop)
    }
}
