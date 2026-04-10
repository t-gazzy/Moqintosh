//
//  TransportBiStreamDelegate.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// Receives inbound data events from a TransportBiStream.
protocol TransportBiStreamDelegate: AnyObject {
    func stream(_ stream: TransportBiStream, didReceive bytes: Data)
}
