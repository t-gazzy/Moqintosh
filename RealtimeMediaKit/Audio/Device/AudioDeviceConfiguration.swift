//
//  AudioDeviceConfiguration.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

struct AudioDeviceConfiguration: Sendable {
    let format: AudioFormat
    let backend: AudioBackendKind
    let inputProcessing: AudioInputProcessing
    let inputEnabled: Bool
    let outputEnabled: Bool

    init(
        format: AudioFormat,
        backend: AudioBackendKind,
        inputProcessing: AudioInputProcessing,
        inputEnabled: Bool,
        outputEnabled: Bool
    ) {
        self.format = format
        self.backend = backend
        self.inputProcessing = inputProcessing
        self.inputEnabled = inputEnabled
        self.outputEnabled = outputEnabled
    }
}
