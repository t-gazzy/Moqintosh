//
//  RemoteIOAudioBackend.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import AudioToolbox
import Foundation

final class RemoteIOAudioBackend: AudioUnitBackend {
    override var componentDescription: AudioComponentDescription {
        AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_RemoteIO,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
    }
}
