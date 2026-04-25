//
//  SystemAudioSessionController.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

#if canImport(AVFAudio)
import AVFAudio
#endif

final class SystemAudioSessionController {
    func activateForCaptureAndPlayback() throws {
        #if canImport(AVFAudio) && (os(iOS) || os(tvOS) || os(visionOS))
        let session: AVAudioSession = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .videoChat,
            options: [.defaultToSpeaker, .allowBluetoothHFP]
        )
        try session.setActive(true)
        #endif
    }

    func deactivate() throws {
        #if canImport(AVFAudio) && (os(iOS) || os(tvOS) || os(visionOS))
        let session: AVAudioSession = AVAudioSession.sharedInstance()
        try session.setActive(false)
        #endif
    }
}
