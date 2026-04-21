//
//  VideoToolboxH264Decoder.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

final class VideoToolboxH264Decoder: InternalVideoFrameDecoding {
    private var currentParameterSets: H264ParameterSets?
    private var formatDescription: CMFormatDescription?
    private var decompressionSession: VTDecompressionSession?

    init() {
        self.currentParameterSets = nil
        self.formatDescription = nil
        self.decompressionSession = nil
    }

    func decode(_ packet: VideoEncodedPacket) async throws -> VideoFrame {
        try prepareDecoderIfNeeded(packet: packet)

        guard let decompressionSession, let formatDescription else {
            OSLogger.error("H264 decoder could not decode because parameter sets are missing.")
            throw VideoDeviceError.missingH264ParameterSets
        }

        let sampleBuffer: CMSampleBuffer = try Self.makeSampleBuffer(
            packet: packet,
            formatDescription: formatDescription
        )
        let sourceFormat: VideoFormat = packet.sourceFormat

        return try await withCheckedThrowingContinuation { continuation in
            let status: OSStatus = VTDecompressionSessionDecodeFrame(
                decompressionSession,
                sampleBuffer: sampleBuffer,
                flags: [],
                infoFlagsOut: nil
            ) { status, infoFlags, imageBuffer, presentationTime, presentationDuration in
                guard status == noErr else {
                    OSLogger.error("Failed to decode H264 frame. status=\(status)")
                    continuation.resume(throwing: VideoDeviceError.videoDecodingFailed(status: status))
                    return
                }

                guard !infoFlags.contains(.frameDropped), let imageBuffer else {
                    OSLogger.warn("H264 decoder dropped a frame.")
                    continuation.resume(throwing: VideoDeviceError.videoDecodingDroppedFrame)
                    return
                }

                let frame: VideoFrame = VideoFrame(
                    pixelBuffer: imageBuffer,
                    presentationTime: presentationTime,
                    duration: presentationDuration.isValid ? presentationDuration : Self.defaultDuration(format: sourceFormat)
                )
                continuation.resume(returning: frame)
            }

            guard status == noErr else {
                OSLogger.error("Failed to submit H264 packet. status=\(status)")
                continuation.resume(throwing: VideoDeviceError.videoDecodingFailed(status: status))
                return
            }
        }
    }

    func finish() async throws {
        guard let decompressionSession else {
            return
        }

        VTDecompressionSessionFinishDelayedFrames(decompressionSession)
        let status: OSStatus = VTDecompressionSessionWaitForAsynchronousFrames(decompressionSession)
        guard status == noErr else {
            OSLogger.error("Failed to finish H264 decoder. status=\(status)")
            throw VideoDeviceError.videoDecodingFailed(status: status)
        }
    }

    deinit {
        OSLogger.debug("Disposing H264 video decoder.")
        if let decompressionSession {
            VTDecompressionSessionInvalidate(decompressionSession)
        }
    }
}

extension VideoToolboxH264Decoder {
    private func prepareDecoderIfNeeded(packet: VideoEncodedPacket) throws {
        if let parameterSets: H264ParameterSets = packet.parameterSets,
           parameterSets != currentParameterSets {
            try resetDecoder(parameterSets: parameterSets)
            return
        }

        guard decompressionSession != nil else {
            OSLogger.error("H264 decoder received a packet before SPS/PPS were available.")
            throw VideoDeviceError.missingH264ParameterSets
        }
    }

    private func resetDecoder(parameterSets: H264ParameterSets) throws {
        if let decompressionSession {
            VTDecompressionSessionInvalidate(decompressionSession)
        }

        let formatDescription: CMFormatDescription = try Self.makeFormatDescription(parameterSets: parameterSets)
        var session: VTDecompressionSession?
        let status: OSStatus = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDescription,
            decoderSpecification: nil,
            imageBufferAttributes: nil,
            decompressionSessionOut: &session
        )

        guard status == noErr, let session else {
            OSLogger.error("Failed to create H264 decoder. status=\(status)")
            throw VideoDeviceError.videoDecodingFailed(status: status)
        }

        self.currentParameterSets = parameterSets
        self.formatDescription = formatDescription
        self.decompressionSession = session
        OSLogger.info("Created H264 video decoder.")
    }

    private static func makeFormatDescription(parameterSets: H264ParameterSets) throws -> CMFormatDescription {
        let sequenceParameterSet: Data = parameterSets.sequenceParameterSet
        let pictureParameterSet: Data = parameterSets.pictureParameterSet
        return try sequenceParameterSet.withUnsafeBytes { sequenceBuffer in
            try pictureParameterSet.withUnsafeBytes { pictureBuffer in
                guard let sequenceBaseAddress: UnsafeRawPointer = sequenceBuffer.baseAddress,
                      let pictureBaseAddress: UnsafeRawPointer = pictureBuffer.baseAddress else {
                    throw VideoDeviceError.missingH264ParameterSets
                }

                let parameterSetPointers: [UnsafePointer<UInt8>] = [
                    sequenceBaseAddress.assumingMemoryBound(to: UInt8.self),
                    pictureBaseAddress.assumingMemoryBound(to: UInt8.self)
                ]
                let parameterSetSizes: [Int] = [sequenceParameterSet.count, pictureParameterSet.count]
                var formatDescription: CMFormatDescription?
                let status: OSStatus = parameterSetPointers.withUnsafeBufferPointer { pointerBuffer in
                    parameterSetSizes.withUnsafeBufferPointer { sizeBuffer in
                        guard let pointerBaseAddress: UnsafePointer<UnsafePointer<UInt8>> = pointerBuffer.baseAddress,
                              let sizeBaseAddress: UnsafePointer<Int> = sizeBuffer.baseAddress else {
                            return kCMFormatDescriptionBridgeError_InvalidParameter
                        }

                        return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                            allocator: kCFAllocatorDefault,
                            parameterSetCount: parameterSetPointers.count,
                            parameterSetPointers: pointerBaseAddress,
                            parameterSetSizes: sizeBaseAddress,
                            nalUnitHeaderLength: 4,
                            formatDescriptionOut: &formatDescription
                        )
                    }
                }

                guard status == noErr, let formatDescription else {
                    OSLogger.error("Failed to create H264 format description. status=\(status)")
                    throw VideoDeviceError.videoDecodingFailed(status: status)
                }

                return formatDescription
            }
        }
    }

    private static func makeSampleBuffer(
        packet: VideoEncodedPacket,
        formatDescription: CMFormatDescription
    ) throws -> CMSampleBuffer {
        var blockBuffer: CMBlockBuffer?
        let blockStatus: OSStatus = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: packet.payload.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: packet.payload.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard blockStatus == noErr, let blockBuffer else {
            OSLogger.error("Failed to create H264 decode block buffer. status=\(blockStatus)")
            throw VideoDeviceError.videoDecodingFailed(status: blockStatus)
        }

        let replaceStatus: OSStatus = packet.payload.withUnsafeBytes { rawBuffer in
            guard let baseAddress: UnsafeRawPointer = rawBuffer.baseAddress else {
                return kCMBlockBufferBadPointerParameterErr
            }

            return CMBlockBufferReplaceDataBytes(
                with: baseAddress,
                blockBuffer: blockBuffer,
                offsetIntoDestination: 0,
                dataLength: packet.payload.count
            )
        }

        guard replaceStatus == noErr else {
            OSLogger.error("Failed to copy H264 packet payload into block buffer. status=\(replaceStatus)")
            throw VideoDeviceError.videoDecodingFailed(status: replaceStatus)
        }

        var timing: CMSampleTimingInfo = CMSampleTimingInfo(
            duration: packet.duration,
            presentationTimeStamp: packet.presentationTime,
            decodeTimeStamp: CMTime.invalid
        )
        var sampleSize: Int = packet.payload.count
        var sampleBuffer: CMSampleBuffer?
        let sampleStatus: OSStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )

        guard sampleStatus == noErr, let sampleBuffer else {
            OSLogger.error("Failed to create H264 decode sample buffer. status=\(sampleStatus)")
            throw VideoDeviceError.videoDecodingFailed(status: sampleStatus)
        }

        return sampleBuffer
    }

    private static func defaultDuration(format: VideoFormat) -> CMTime {
        CMTime(value: 1, timescale: CMTimeScale(format.framesPerSecond))
    }
}
