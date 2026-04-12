//
//  GroupOrder.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

/// The ordering semantics requested or advertised for groups within a track.
public enum GroupOrder: UInt8, Sendable {
    case publisherDefault = 0x00
    case ascending = 0x01
    case descending = 0x02
}
