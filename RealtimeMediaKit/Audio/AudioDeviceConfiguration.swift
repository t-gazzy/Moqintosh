//
//  AudioDeviceConfiguration.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

public struct AudioDeviceConfiguration: Sendable {
    public let format: AudioFormat
    public let backend: AudioBackendKind
    public let inputProcessing: AudioInputProcessing
    public let inputEnabled: Bool
    public let outputEnabled: Bool

    public init(
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
