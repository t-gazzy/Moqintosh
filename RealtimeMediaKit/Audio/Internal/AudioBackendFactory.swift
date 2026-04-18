//
//  AudioBackendFactory.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

enum AudioBackendFactory {
    static func makeBackend(configuration: AudioDeviceConfiguration) throws -> any InternalAudioBackend {
        switch (configuration.backend, configuration.inputProcessing) {
        case (.remoteIO, .raw):
            return RemoteIOAudioBackend(configuration: configuration)
        case (.voiceProcessingIO, .voiceProcessed):
            return VoiceProcessingAudioBackend(configuration: configuration)
        default:
            throw AudioDeviceError.backendMismatch
        }
    }
}
