//
//  TransportConnectionDelegate.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// Receives inbound data-plane events from a TransportConnection.
protocol TransportConnectionDelegate: AnyObject {
    func connection(_ connection: TransportConnection, didReceiveUniStream stream: TransportUniStream)
    func connection(_ connection: TransportConnection, didReceiveDatagram bytes: Data)
}
