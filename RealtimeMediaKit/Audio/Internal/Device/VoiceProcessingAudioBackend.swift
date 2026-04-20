//
//  VoiceProcessingAudioBackend.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import AudioToolbox
import Foundation

final class VoiceProcessingAudioBackend: AudioUnitBackend {
    override var componentDescription: AudioComponentDescription {
        AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_VoiceProcessingIO,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
    }
}
