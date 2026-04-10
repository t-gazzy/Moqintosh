//
//  Data+ReadExtension.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2025/01/16.
//

import Foundation

enum DataReadError: Error {
    case insufficientData(requested: Int, available: Int)
    case invalidUTF8
}

extension Data {

    /// Decodes a QUIC variable-length integer (RFC 9000 Section 16).
    /// The top 2 bits of the first byte indicate the total byte length:
    ///   00 → 1 byte, 01 → 2 bytes, 10 → 4 bytes, 11 → 8 bytes
    func readVarint(at offset: inout Int) throws -> Int {
        guard offset < self.count else {
            throw DataReadError.insufficientData(requested: 1, available: self.count - offset)
        }

        let head = self[self.startIndex + offset]

        switch head >> 6 {
        case 0:
            // 1 byte (6 effective bits)
            return Int(try readUInt8(at: &offset))

        case 1:
            // 2 bytes (14 effective bits)
            return Int(try readUInt16(at: &offset) & 0x3FFF)

        case 2:
            // 4 bytes (30 effective bits)
            return Int(try readUInt32(at: &offset) & 0x3FFF_FFFF)

        case 3:
            // 8 bytes (62 effective bits)
            return Int(bitPattern: UInt(try readUInt64(at: &offset) & 0x3FFF_FFFF_FFFF_FFFF))

        default:
            // The top 2 bits are always in range 0...3, so this is unreachable
            fatalError("unreachable")
        }
    }

    /// Decodes a UTF-8 string.
    /// The byte length of the string is prefixed as a variable-length integer.
    func readString(at offset: inout Int) throws -> String {
        let length: Int = try readVarint(at: &offset)

        guard offset + length <= self.count else {
            throw DataReadError.insufficientData(requested: length, available: self.count - offset)
        }

        let range = (self.startIndex + offset) ..< (self.startIndex + offset + length)
        let bytes = self[range]
        offset += length

        guard let string = String(bytes: bytes, encoding: .utf8) else {
            throw DataReadError.invalidUTF8
        }

        return string
    }

    // MARK: - Primitive readers

    private func readUInt8(at offset: inout Int) throws -> UInt8 {
        guard offset + 1 <= self.count else {
            throw DataReadError.insufficientData(requested: 1, available: self.count - offset)
        }
        let value = self[self.startIndex + offset]
        offset += 1
        return value
    }

    private func readUInt16(at offset: inout Int) throws -> UInt16 {
        let size: Int = 2
        guard offset + size <= self.count else {
            throw DataReadError.insufficientData(requested: size, available: self.count - offset)
        }
        let value = self[self.startIndex + offset ..< self.startIndex + offset + size]
            .withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }
        offset += size
        return UInt16(bigEndian: value)
    }

    private func readUInt32(at offset: inout Int) throws -> UInt32 {
        let size: Int = 4
        guard offset + size <= self.count else {
            throw DataReadError.insufficientData(requested: size, available: self.count - offset)
        }
        let value = self[self.startIndex + offset ..< self.startIndex + offset + size]
            .withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        offset += size
        return UInt32(bigEndian: value)
    }

    private func readUInt64(at offset: inout Int) throws -> UInt64 {
        let size: Int = 8
        guard offset + size <= self.count else {
            throw DataReadError.insufficientData(requested: size, available: self.count - offset)
        }
        let value = self[self.startIndex + offset ..< self.startIndex + offset + size]
            .withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }
        offset += size
        return UInt64(bigEndian: value)
    }
}
