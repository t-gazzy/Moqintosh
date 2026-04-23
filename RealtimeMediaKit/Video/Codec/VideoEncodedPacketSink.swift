//
//  VideoEncodedPacketSink.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

public protocol VideoEncodedPacketSink: AnyObject {
    func handleEncodedPacket(_ packet: VideoEncodedPacket)
}
