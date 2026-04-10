//
//  TransportConnectionDelegate.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

/// Receives inbound stream events from a TransportConnection.
protocol TransportConnectionDelegate: AnyObject {
    func connection(_ connection: TransportConnection, didReceiveUniStream stream: TransportUniStream)
}
