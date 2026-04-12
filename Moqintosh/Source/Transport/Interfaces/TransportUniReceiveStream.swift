//
//  TransportUniReceiveStream.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

struct TransportUniReceiveResult: Sendable {

    let bytes: Data
    let isComplete: Bool
}

/// Represents an inbound unidirectional transport stream.
protocol TransportUniReceiveStream: AnyObject, Sendable {
    func receive() async throws -> TransportUniReceiveResult
}
