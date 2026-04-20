//
//  SystemAudioDevice.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

public final class SystemAudioDevice: AudioDevice {
    public let configuration: AudioDeviceConfiguration
    public let pipeline: AudioPipeline
    public weak var renderSource: (any AudioFrameSource)?

    private let backend: any InternalAudioBackend

    public init(
        configuration: AudioDeviceConfiguration,
        pipeline: AudioPipeline = AudioPipeline()
    ) throws {
        self.configuration = configuration
        self.pipeline = pipeline
        self.backend = try AudioBackendFactory.makeBackend(configuration: configuration)
        self.backend.client = self
        OSLogger.debug("Created system audio device. backend=\(configuration.backend) inputEnabled=\(configuration.inputEnabled) outputEnabled=\(configuration.outputEnabled)")
    }

    public func start() throws {
        OSLogger.info("Starting system audio device.")
        try backend.start()
        OSLogger.info("System audio device started.")
    }

    public func stop() throws {
        OSLogger.info("Stopping system audio device.")
        try backend.stop()
        OSLogger.info("System audio device stopped.")
    }
}

extension SystemAudioDevice: AudioBackendClient {
    func audioBackend(_ backend: any InternalAudioBackend, didCapture frame: inout AudioFrame) {
        pipeline.processCapture(&frame)
    }

    func audioBackend(_ backend: any InternalAudioBackend, willRender frame: inout AudioFrame) {
        renderSource?.render(into: &frame)
        pipeline.processRender(&frame)
    }
}
