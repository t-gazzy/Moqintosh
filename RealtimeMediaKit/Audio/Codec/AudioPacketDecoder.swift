//
//  AudioPacketDecoder.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

public protocol AudioPacketDecoder: AnyObject {
    func decode(_ packet: AudioEncodedPacket) throws -> AudioFrame
}
