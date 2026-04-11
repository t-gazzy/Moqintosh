//
//  TransportUniSendStream.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Represents an open outbound unidirectional transport stream.
protocol TransportUniSendStream: AnyObject {
    func send(bytes: Data, endOfStream: Bool) async throws
}
