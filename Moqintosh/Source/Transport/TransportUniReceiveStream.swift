//
//  TransportUniReceiveStream.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

struct TransportUniReceiveResult {

    let bytes: Data
    let isComplete: Bool
}

/// Represents an inbound unidirectional transport stream.
protocol TransportUniReceiveStream: AnyObject {
    func receive() async throws -> TransportUniReceiveResult
}
