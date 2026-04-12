//
//  TransportBiStream.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// Represents an open bidirectional transport stream.
protocol TransportBiStream: AnyObject, Sendable {
    /// Receives the next raw chunk of bytes from the stream.
    /// Throws when the stream is closed or an error occurs.
    func receive() async throws -> Data
    func send(bytes: Data) async throws
}
