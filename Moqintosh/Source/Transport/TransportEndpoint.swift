//
//  TransportEndpoint.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

/// Abstraction over the underlying transport layer.
protocol TransportEndpoint: AnyObject {
    func connect() async throws -> TransportConnection
}
