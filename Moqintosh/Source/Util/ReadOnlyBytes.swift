//
//  ReadOnlyBytes.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

public struct ReadOnlyBytes: Sendable, Equatable {

    let storage: Data
    let offset: Int
    let count: Int

    public init(_ storage: Data) {
        self.storage = storage
        self.offset = 0
        self.count = storage.count
    }

    init(storage: Data, offset: Int, count: Int) {
        self.storage = storage
        self.offset = offset
        self.count = count
    }

    public var data: Data {
        let lowerBound: Int = storage.startIndex + offset
        let upperBound: Int = lowerBound + count
        return storage.subdata(in: lowerBound ..< upperBound)
    }

    public func materialize() -> Data {
        data
    }

    public var utf8String: String? {
        withUnsafeBytes { rawBuffer in
            let bytes: UnsafeBufferPointer<UInt8> = rawBuffer.bindMemory(to: UInt8.self)
            return String(bytes: bytes, encoding: .utf8)
        }
    }

    public func withUnsafeBytes<Result>(
        _ body: (UnsafeRawBufferPointer) throws -> Result
    ) rethrows -> Result {
        try storage.withUnsafeBytes { rawBuffer in
            let slice: UnsafeRawBufferPointer = UnsafeRawBufferPointer(
                start: rawBuffer.baseAddress?.advanced(by: offset),
                count: count
            )
            return try body(slice)
        }
    }

    func append(to data: inout Data) {
        withUnsafeBytes { rawBuffer in
            data.append(rawBuffer.bindMemory(to: UInt8.self))
        }
    }

    public func equals(_ data: Data) -> Bool {
        count == data.count && withUnsafeBytes { rawBuffer in
            data.withUnsafeBytes { dataRawBuffer in
                rawBuffer.elementsEqual(dataRawBuffer)
            }
        }
    }

    public static func == (lhs: ReadOnlyBytes, rhs: ReadOnlyBytes) -> Bool {
        lhs.count == rhs.count && lhs.data == rhs.data
    }
}
