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

    private let backend: any InternalAudioBackend

    public init(
        configuration: AudioDeviceConfiguration,
        pipeline: AudioPipeline = AudioPipeline()
    ) throws {
        self.configuration = configuration
        self.pipeline = pipeline
        self.backend = try AudioBackendFactory.makeBackend(configuration: configuration)
        self.backend.client = self
    }

    public func start() throws {
        try backend.start()
    }

    public func stop() throws {
        try backend.stop()
    }
}

extension SystemAudioDevice: AudioBackendClient {
    func audioBackend(_ backend: any InternalAudioBackend, didCapture frame: inout AudioFrame) {
        pipeline.processCapture(&frame)
    }

    func audioBackend(_ backend: any InternalAudioBackend, willRender frame: inout AudioFrame) {
        pipeline.processRender(&frame)
    }
}
