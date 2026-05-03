//
//  SystemAudioSessionController.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

import AVFAudio

enum SystemAudioSessionConfiguration {
    case captureAndPlaybackVideoChat
}

extension SystemAudioSessionConfiguration {
    fileprivate var category: AVAudioSession.Category {
        switch self {
        case .captureAndPlaybackVideoChat:
            return .playAndRecord
        }
    }

    fileprivate var mode: AVAudioSession.Mode {
        switch self {
        case .captureAndPlaybackVideoChat:
            return .videoChat
        }
    }

    fileprivate var options: AVAudioSession.CategoryOptions {
        switch self {
        case .captureAndPlaybackVideoChat:
            return [.defaultToSpeaker, .allowBluetoothHFP]
        }
    }
}

final class SystemAudioSessionController {
    func activateForCaptureAndPlayback() throws {
        try activate(configuration: .captureAndPlaybackVideoChat)
    }

    func activate(configuration: SystemAudioSessionConfiguration) throws {
        #if os(iOS) || os(tvOS) || os(visionOS)
        let session: AVAudioSession = AVAudioSession.sharedInstance()
        try session.setCategory(
            configuration.category,
            mode: configuration.mode,
            options: configuration.options
        )
        try session.setActive(true)
        #endif
    }

    func deactivate() throws {
        #if os(iOS) || os(tvOS) || os(visionOS)
        let session: AVAudioSession = AVAudioSession.sharedInstance()
        try session.setActive(false)
        #endif
    }
}
