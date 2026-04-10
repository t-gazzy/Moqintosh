//
//  TransportUniStream.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// Represents an open unidirectional transport stream.
protocol TransportUniStream: AnyObject {
    func send(bytes: Data) async throws
}
