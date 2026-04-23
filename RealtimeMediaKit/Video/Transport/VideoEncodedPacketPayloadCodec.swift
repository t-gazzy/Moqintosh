//
//  VideoEncodedPacketPayloadCodec.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import CoreMedia
import Foundation

public enum VideoEncodedPacketPayloadCodec {
    public static let headerByteCount: Int = 33

    public static func encode(_ packet: VideoEncodedPacket) -> Data {
        let sequenceParameterSet: Data = packet.parameterSets?.sequenceParameterSet ?? Data()
        let pictureParameterSet: Data = packet.parameterSets?.pictureParameterSet ?? Data()
        var data: Data = Data()
        data.append(packet.isKeyFrame ? 1 : 0)
        append(UInt32(packet.sourceFormat.width), to: &data)
        append(UInt32(packet.sourceFormat.height), to: &data)
        append(UInt32(packet.sourceFormat.framesPerSecond), to: &data)
        append(packet.presentationTime.timescale, to: &data)
        append(packet.duration.timescale, to: &data)
        append(UInt32(sequenceParameterSet.count), to: &data)
        append(UInt32(pictureParameterSet.count), to: &data)
        append(UInt32(packet.payload.count), to: &data)
        data.append(sequenceParameterSet)
        data.append(pictureParameterSet)
        data.append(packet.payload)
        return data
    }

    public static func decode(_ packet: TimedMediaPacket) throws -> VideoEncodedPacket {
        let payload: Data = packet.payload
        guard payload.count >= headerByteCount else {
            throw VideoEncodedPacketPayloadCodecError.insufficientData(
                requiredByteCount: headerByteCount,
                actualByteCount: payload.count
            )
        }

        var offset: Int = 0
        let isKeyFrame: Bool = readUInt8(from: payload, offset: &offset) != 0
        let width: UInt32 = readUInt32(from: payload, offset: &offset)
        let height: UInt32 = readUInt32(from: payload, offset: &offset)
        let framesPerSecond: UInt32 = readUInt32(from: payload, offset: &offset)
        let presentationTimescale: Int32 = readInt32(from: payload, offset: &offset)
        let durationTimescale: Int32 = readInt32(from: payload, offset: &offset)
        let sequenceParameterSetByteCount: Int = Int(readUInt32(from: payload, offset: &offset))
        let pictureParameterSetByteCount: Int = Int(readUInt32(from: payload, offset: &offset))
        let encodedPayloadByteCount: Int = Int(readUInt32(from: payload, offset: &offset))
        let requiredByteCount: Int = headerByteCount
            + sequenceParameterSetByteCount
            + pictureParameterSetByteCount
            + encodedPayloadByteCount

        guard payload.count >= requiredByteCount else {
            throw VideoEncodedPacketPayloadCodecError.insufficientData(
                requiredByteCount: requiredByteCount,
                actualByteCount: payload.count
            )
        }

        guard width > 0, height > 0, framesPerSecond > 0 else {
            throw VideoEncodedPacketPayloadCodecError.invalidFormat(
                width: width,
                height: height,
                framesPerSecond: framesPerSecond
            )
        }

        let sequenceParameterSet: Data = readData(
            from: payload,
            offset: &offset,
            byteCount: sequenceParameterSetByteCount
        )
        let pictureParameterSet: Data = readData(
            from: payload,
            offset: &offset,
            byteCount: pictureParameterSetByteCount
        )
        let encodedPayload: Data = readData(from: payload, offset: &offset, byteCount: encodedPayloadByteCount)
        let parameterSets: H264ParameterSets? = makeParameterSets(
            sequenceParameterSet: sequenceParameterSet,
            pictureParameterSet: pictureParameterSet
        )

        return VideoEncodedPacket(
            payload: encodedPayload,
            presentationTime: CMTime(value: packet.timestamp, timescale: presentationTimescale),
            duration: CMTime(value: packet.duration, timescale: durationTimescale),
            sourceFormat: VideoFormat(
                width: Int(width),
                height: Int(height),
                framesPerSecond: Int(framesPerSecond)
            ),
            isKeyFrame: isKeyFrame,
            parameterSets: parameterSets
        )
    }

    private static func makeParameterSets(
        sequenceParameterSet: Data,
        pictureParameterSet: Data
    ) -> H264ParameterSets? {
        guard !sequenceParameterSet.isEmpty, !pictureParameterSet.isEmpty else {
            return nil
        }
        return H264ParameterSets(
            sequenceParameterSet: sequenceParameterSet,
            pictureParameterSet: pictureParameterSet
        )
    }

    private static func append(_ value: UInt32, to data: inout Data) {
        var bigEndianValue: UInt32 = value.bigEndian
        withUnsafeBytes(of: &bigEndianValue) { valueBuffer in
            data.append(contentsOf: valueBuffer)
        }
    }

    private static func append(_ value: Int32, to data: inout Data) {
        var bigEndianValue: Int32 = value.bigEndian
        withUnsafeBytes(of: &bigEndianValue) { valueBuffer in
            data.append(contentsOf: valueBuffer)
        }
    }

    private static func readUInt8(from data: Data, offset: inout Int) -> UInt8 {
        let value: UInt8 = data[data.startIndex + offset]
        offset += MemoryLayout<UInt8>.size
        return value
    }

    private static func readUInt32(from data: Data, offset: inout Int) -> UInt32 {
        let size: Int = MemoryLayout<UInt32>.size
        let value: UInt32 = data[data.startIndex + offset ..< data.startIndex + offset + size]
            .withUnsafeBytes { rawBuffer in
                rawBuffer.loadUnaligned(as: UInt32.self)
            }
        offset += size
        return UInt32(bigEndian: value)
    }

    private static func readInt32(from data: Data, offset: inout Int) -> Int32 {
        let size: Int = MemoryLayout<Int32>.size
        let value: Int32 = data[data.startIndex + offset ..< data.startIndex + offset + size]
            .withUnsafeBytes { rawBuffer in
                rawBuffer.loadUnaligned(as: Int32.self)
            }
        offset += size
        return Int32(bigEndian: value)
    }

    private static func readData(from data: Data, offset: inout Int, byteCount: Int) -> Data {
        let range: Range<Data.Index> = data.startIndex + offset ..< data.startIndex + offset + byteCount
        offset += byteCount
        return data.subdata(in: range)
    }
}
