//
//  RealtimeMediaPacketPayloadCodec.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation

public enum RealtimeMediaPacketPayloadCodec {
    public static let headerByteCount: Int = 16

    public static func encode(_ packet: TimedMediaPacket) -> Data {
        var data: Data = Data()
        append(packet.timestamp, to: &data)
        append(packet.duration, to: &data)
        data.append(packet.payload)
        return data
    }

    public static func decode(sequenceNumber: UInt64, payload: Data) throws -> TimedMediaPacket {
        guard payload.count >= headerByteCount else {
            throw RealtimeMediaPacketPayloadCodecError.insufficientData(
                requiredByteCount: headerByteCount,
                actualByteCount: payload.count
            )
        }

        let timestamp: Int64 = readInt64(from: payload, offset: 0)
        let duration: Int64 = readInt64(from: payload, offset: MemoryLayout<Int64>.size)
        let mediaPayload: Data = payload.subdata(in: headerByteCount ..< payload.count)
        return TimedMediaPacket(
            sequenceNumber: sequenceNumber,
            timestamp: timestamp,
            duration: duration,
            payload: mediaPayload
        )
    }

    private static func append(_ value: Int64, to data: inout Data) {
        var bigEndianValue: Int64 = value.bigEndian
        withUnsafeBytes(of: &bigEndianValue) { valueBuffer in
            data.append(contentsOf: valueBuffer)
        }
    }

    private static func readInt64(from data: Data, offset: Int) -> Int64 {
        let size: Int = MemoryLayout<Int64>.size
        let value: Int64 = data[data.startIndex + offset ..< data.startIndex + offset + size]
            .withUnsafeBytes { rawBuffer in
                rawBuffer.loadUnaligned(as: Int64.self)
            }
        return Int64(bigEndian: value)
    }
}
