//
//  AudioBackendFactory.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

enum AudioBackendFactory {
    static func makeBackend(configuration: AudioDeviceConfiguration) throws -> any InternalAudioBackend {
        OSLogger.debug("Creating audio backend. backend=\(configuration.backend) inputProcessing=\(configuration.inputProcessing)")

        switch (configuration.backend, configuration.inputProcessing) {
        case (.remoteIO, .raw):
            return RemoteIOAudioBackend(configuration: configuration)
        case (.voiceProcessingIO, .voiceProcessed):
            return VoiceProcessingAudioBackend(configuration: configuration)
        default:
            OSLogger.error("Failed to create audio backend because backend and input processing do not match.")
            throw AudioDeviceError.backendMismatch
        }
    }
}
