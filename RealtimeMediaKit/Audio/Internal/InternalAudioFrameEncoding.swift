//
//  InternalAudioFrameEncoding.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

protocol InternalAudioFrameEncoding: AnyObject {
    func encode(_ frame: AudioFrame) throws -> AudioEncodedPacket
}
