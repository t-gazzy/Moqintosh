//
//  ByteReader.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// A stateful cursor over a `Data` buffer.
///
/// Encapsulates both the data and the current read position,
/// eliminating the need to pass an `offset` alongside every read call.
///
/// ### Usage
/// ```swift
/// let reader = ByteReader(data: payload)
/// let type   = try reader.readVarint()
/// let count  = try reader.readVarint()
/// let name   = try reader.readString()
/// ```
final class ByteReader {

    private let data: Data
    private var offset: Int = 0

    var consumedCount: Int { offset }

    /// The number of bytes not yet consumed.
    var remainingCount: Int { data.count - offset }

    init(data: Data) {
        self.data = data
    }

    // MARK: - Public readers

    /// Decodes a QUIC variable-length integer (RFC 9000 Section 16).
    func readVarint() throws -> UInt64 {
        guard offset < data.count else {
            throw ByteReaderError.insufficientData(requested: 1, available: remainingCount)
        }
        let head = data[data.startIndex + offset]
        switch head >> 6 {
        case 0:
            return UInt64(try readUInt8())
        case 1:
            return UInt64(try readUInt16() & 0x3FFF)
        case 2:
            return UInt64(try readUInt32() & 0x3FFF_FFFF)
        case 3:
            return try readUInt64() & 0x3FFF_FFFF_FFFF_FFFF
        default:
            fatalError("unreachable")
        }
    }

    /// Decodes a big-endian UInt16.
    func readUInt16BE() throws -> UInt16 {
        try readUInt16()
    }

    /// Reads `length` raw bytes.
    func readBytes(length: Int) throws -> Data {
        guard offset + length <= data.count else {
            throw ByteReaderError.insufficientData(requested: length, available: remainingCount)
        }
        let slice = data[data.startIndex + offset ..< data.startIndex + offset + length]
        offset += length
        return slice
    }

    /// Decodes a UTF-8 string whose byte length is prefixed as a varint.
    func readString() throws -> String {
        let length = Int(try readVarint())
        let bytes = try readBytes(length: length)
        guard let string = String(bytes: bytes, encoding: .utf8) else {
            throw ByteReaderError.invalidUTF8
        }
        return string
    }

    func readUInt8Value() throws -> UInt8 {
        try readUInt8()
    }

    // MARK: - Private primitive readers

    private func readUInt8() throws -> UInt8 {
        guard offset + 1 <= data.count else {
            throw ByteReaderError.insufficientData(requested: 1, available: remainingCount)
        }
        let value = data[data.startIndex + offset]
        offset += 1
        return value
    }

    private func readUInt16() throws -> UInt16 {
        let size: Int = 2
        guard offset + size <= data.count else {
            throw ByteReaderError.insufficientData(requested: size, available: remainingCount)
        }
        let value = data[data.startIndex + offset ..< data.startIndex + offset + size]
            .withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }
        offset += size
        return UInt16(bigEndian: value)
    }

    private func readUInt32() throws -> UInt32 {
        let size: Int = 4
        guard offset + size <= data.count else {
            throw ByteReaderError.insufficientData(requested: size, available: remainingCount)
        }
        let value = data[data.startIndex + offset ..< data.startIndex + offset + size]
            .withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        offset += size
        return UInt32(bigEndian: value)
    }

    private func readUInt64() throws -> UInt64 {
        let size: Int = 8
        guard offset + size <= data.count else {
            throw ByteReaderError.insufficientData(requested: size, available: remainingCount)
        }
        let value = data[data.startIndex + offset ..< data.startIndex + offset + size]
            .withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }
        offset += size
        return UInt64(bigEndian: value)
    }
}

enum ByteReaderError: Error {
    case insufficientData(requested: Int, available: Int)
    case invalidUTF8
}
