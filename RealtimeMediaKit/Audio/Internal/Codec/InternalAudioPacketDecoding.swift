//
//  InternalAudioPacketDecoding.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

protocol InternalAudioPacketDecoding: AnyObject, Sendable {
    func decode(_ packet: AudioEncodedPacket) throws -> AudioFrame
}
