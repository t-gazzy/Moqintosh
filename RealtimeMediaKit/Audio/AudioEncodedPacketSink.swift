//
//  AudioEncodedPacketSink.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

public protocol AudioEncodedPacketSink: AnyObject {
    func handleEncodedPacket(_ packet: AudioEncodedPacket)
}
