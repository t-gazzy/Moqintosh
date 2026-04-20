//
//  AudioUnitComponentDescribing.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import AudioToolbox
import Foundation

protocol AudioUnitComponentDescribing {
    var componentDescription: AudioComponentDescription { get }
}
