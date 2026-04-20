//
//  AudioDeviceError.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

public enum AudioDeviceError: Error {
    case alreadyRunning
    case notRunning
    case backendMismatch
    case unsupportedFormat
    case audioEncodingFailed(status: Int32)
    case audioDecodingFailed(status: Int32)
    case audioComponentNotFound
    case audioUnitCreationFailed
    case audioUnitInitializationFailed(status: Int32)
    case audioUnitStartFailed(status: Int32)
    case audioUnitStopFailed(status: Int32)
    case audioUnitConfigurationFailed(status: Int32)
}
