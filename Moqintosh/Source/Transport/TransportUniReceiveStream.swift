//
//  TransportUniReceiveStream.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Represents an inbound unidirectional transport stream.
protocol TransportUniReceiveStream: AnyObject {
    func receive() async throws -> Data
}
