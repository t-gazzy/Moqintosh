//
//  Data+WriteExtension.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

extension Data {

    /// Encodes a value as a QUIC variable-length integer (RFC 9000 Section 16) and appends it.
    mutating func writeVarint(_ value: UInt64) {
        if value < 0x40 {
            append(UInt8(value))
        } else if value < 0x4000 {
            writeUInt16(UInt16(value ^ 0x4000))
        } else if value < 0x4000_0000 {
            writeUInt32(UInt32(value ^ 0x8000_0000))
        } else if value < 0x4000_0000_0000_0000 {
            writeUInt64(value ^ 0xC000_0000_0000_0000)
        } else {
            preconditionFailure("Value \(value) is too large for a QUIC variable-length integer")
        }
    }

    /// Encodes a string as a length-prefixed UTF-8 byte sequence and appends it.
    mutating func writeString(_ value: String) {
        let bytes = Array(value.utf8)
        writeVarint(UInt64(bytes.count))
        append(contentsOf: bytes)
    }

    // MARK: - Primitive writers

    private mutating func writeUInt16(_ value: UInt16) {
        var bigEndian = value.bigEndian
        append(contentsOf: Swift.withUnsafeBytes(of: &bigEndian) { Array($0) })
    }

    private mutating func writeUInt32(_ value: UInt32) {
        var bigEndian = value.bigEndian
        append(contentsOf: Swift.withUnsafeBytes(of: &bigEndian) { Array($0) })
    }

    private mutating func writeUInt64(_ value: UInt64) {
        var bigEndian = value.bigEndian
        append(contentsOf: Swift.withUnsafeBytes(of: &bigEndian) { Array($0) })
    }
}
