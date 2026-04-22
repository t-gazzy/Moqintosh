//
//  RealtimeMediaPacketPayloadCodecError.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

public enum RealtimeMediaPacketPayloadCodecError: Error, Equatable {
    case insufficientData(requiredByteCount: Int, actualByteCount: Int)
}
