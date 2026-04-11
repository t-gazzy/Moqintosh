//
//  TransportConnection.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// Represents an established transport connection.
protocol TransportConnection: AnyObject {
    var delegate: (any TransportConnectionDelegate)? { get set }
    func openBiStream() async throws -> TransportBiStream
    func openUniStream() async throws -> TransportUniSendStream
    func sendDatagram(bytes: Data) async throws
}
