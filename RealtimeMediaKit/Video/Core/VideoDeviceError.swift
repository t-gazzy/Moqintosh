//
//  VideoDeviceError.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import Foundation

public enum VideoDeviceError: Error {
    case alreadyRunning
    case notRunning
    case cameraAccessDenied
    case cameraUnavailable
    case captureConfigurationFailed
    case unsupportedFormat
    case videoEncodingFailed(status: Int32)
    case videoEncodingDroppedFrame
    case videoDecodingFailed(status: Int32)
    case videoDecodingDroppedFrame
    case missingEncodedFrameData
    case missingDecodedFrameData
    case missingH264ParameterSets
}
