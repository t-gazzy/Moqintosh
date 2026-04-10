//
//  TransportBiStream.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// Represents an open bidirectional transport stream.
protocol TransportBiStream: AnyObject {
    var delegate: (any TransportBiStreamDelegate)? { get set }
    func send(bytes: Data) async throws
}
