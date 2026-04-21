//
//  CameraPosition.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import AVFoundation
import Foundation

public enum CameraPosition: Sendable {
    case front
    case back
    case unspecified
}

extension CameraPosition {
    var avCapturePosition: AVCaptureDevice.Position {
        switch self {
        case .front:
            return .front
        case .back:
            return .back
        case .unspecified:
            return .unspecified
        }
    }
}
