//
//  TrackNamespace.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// An ordered N-tuple of byte fields that identifies a track namespace (Section 2.4.1).
///
/// Wire format (tuple):
/// ```
/// Tuple {
///   Number of Elements (i),
///   [Element Length (i), Element Value (..)] ...
/// }
/// ```
/// N must be between 1 and 32 inclusive.
public struct TrackNamespace: Sendable, Equatable {

    let elements: [Data]

    public init(elements: [Data]) {
        precondition(!elements.isEmpty && elements.count <= 32, "TrackNamespace must have 1–32 elements")
        self.elements = elements
    }

    /// Convenience initialiser for string-based namespaces (UTF-8 encoded).
    public init(strings: [String]) {
        self.init(elements: strings.map { Data($0.utf8) })
    }

    public var utf8Elements: [String?] {
        elements.map { String(data: $0, encoding: .utf8) }
    }

    public func joinedUTF8Elements(separator: String = "/") -> String {
        utf8Elements
            .map { $0 ?? "<binary>" }
            .joined(separator: separator)
    }

    // MARK: - Encode

    func encode() -> Data {
        var data = Data()
        data.writeVarint(UInt64(elements.count))
        for element in elements {
            data.writeVarint(UInt64(element.count))
            data.append(element)
        }
        return data
    }

    // MARK: - Decode

    static func decode(from reader: ByteReader) throws -> TrackNamespace {
        let count = Int(try reader.readVarint())
        guard count >= 1 && count <= 32 else {
            throw TrackNamespaceError.invalidElementCount(count)
        }
        var elements: [Data] = []
        for _ in 0 ..< count {
            let length = Int(try reader.readVarint())
            elements.append(try reader.readBytes(length: length))
        }
        return TrackNamespace(elements: elements)
    }
}

enum TrackNamespaceError: Error {
    case invalidElementCount(Int)
}
