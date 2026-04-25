//
//  VideoSender.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

public final class VideoSender {
    private let pipeline: VideoSenderPipeline
    private let errorHandler: @Sendable (Error) -> Void
    private var sendTask: Task<Void, Never>?

    public init(
        packetSender: any RealtimeMediaPacketSender,
        format: VideoFormat,
        cameraPosition: CameraPosition = .front,
        bitrate: Int? = 500_000,
        keyFrameInterval: Int = 30,
        errorHandler: @escaping @Sendable (Error) -> Void = { _ in }
    ) throws {
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
            errorHandler: errorHandler
        )

        self.pipeline = VideoSenderPipeline(
            capturer: capturer,
            encoder: encoder,
            sink: sink
        )
        self.errorHandler = errorHandler
        self.sendTask = nil
    }

    deinit {
        sendTask?.cancel()
        pipeline.sink.finish()
        Task {
            try? await pipeline.capturer.stop()
        }
    }

    public func start() async throws {
        guard sendTask == nil else {
            throw VideoDeviceError.alreadyRunning
        }

        try await pipeline.capturer.start()
        let capturer: CameraVideoSource = pipeline.capturer
        let encoder: H264VideoEncoder = pipeline.encoder
        let sink: VideoEncodedPacketSendingHandler = pipeline.sink
        let errorHandler: @Sendable (Error) -> Void = self.errorHandler

        self.sendTask = Task<Void, Never> {
            do {
                for try await frame in capturer.frames {
                    let packet: VideoEncodedPacket = try await encoder.encode(frame)
                    sink.handleEncodedPacket(packet)
                }
            } catch {
                errorHandler(error)
            }
        }
    }

    public func stop() async {
        sendTask?.cancel()
        sendTask = nil
        try? await pipeline.capturer.stop()
    }
}
