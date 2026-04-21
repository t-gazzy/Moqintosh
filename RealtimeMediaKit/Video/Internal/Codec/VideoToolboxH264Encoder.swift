//
//  VideoToolboxH264Encoder.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

final class VideoToolboxH264Encoder: InternalVideoFrameEncoding {
    private let configuration: H264EncoderConfiguration
    private let compressionSession: VTCompressionSession

    init(configuration: H264EncoderConfiguration) throws {
        self.configuration = configuration

        var session: VTCompressionSession?
        let creationStatus: OSStatus = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(configuration.inputFormat.width),
            height: Int32(configuration.inputFormat.height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &session
        )

        guard creationStatus == noErr, let session else {
            OSLogger.error("Failed to create H264 encoder. status=\(creationStatus)")
            throw VideoDeviceError.videoEncodingFailed(status: creationStatus)
        }

        self.compressionSession = session
        try configure(session)
        OSLogger.info("Created H264 video encoder.")
    }

    func encode(_ frame: VideoFrame) async throws -> VideoEncodedPacket {
        try validate(frame: frame)

        let sourceFormat: VideoFormat = configuration.inputFormat
        return try await withCheckedThrowingContinuation { continuation in
            let status: OSStatus = VTCompressionSessionEncodeFrame(
                compressionSession,
                imageBuffer: frame.pixelBuffer,
                presentationTimeStamp: frame.presentationTime,
                duration: frame.duration,
                frameProperties: nil,
                infoFlagsOut: nil
            ) { status, infoFlags, sampleBuffer in
                guard status == noErr else {
                    OSLogger.error("Failed to encode H264 frame. status=\(status)")
                    continuation.resume(throwing: VideoDeviceError.videoEncodingFailed(status: status))
                    return
                }

                guard !infoFlags.contains(.frameDropped), let sampleBuffer else {
                    OSLogger.warn("H264 encoder dropped a frame.")
                    continuation.resume(throwing: VideoDeviceError.videoEncodingDroppedFrame)
                    return
                }

                do {
                    let packet: VideoEncodedPacket = try Self.makePacket(
                        sampleBuffer: sampleBuffer,
                        sourceFormat: sourceFormat
                    )
                    continuation.resume(returning: packet)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            guard status == noErr else {
                OSLogger.error("Failed to submit H264 frame. status=\(status)")
                continuation.resume(throwing: VideoDeviceError.videoEncodingFailed(status: status))
                return
            }
        }
    }

    func finish() async throws {
        let status: OSStatus = VTCompressionSessionCompleteFrames(
            compressionSession,
            untilPresentationTimeStamp: CMTime.invalid
        )

        guard status == noErr else {
            OSLogger.error("Failed to finish H264 encoder. status=\(status)")
            throw VideoDeviceError.videoEncodingFailed(status: status)
        }
    }

    deinit {
        OSLogger.debug("Disposing H264 video encoder.")
        VTCompressionSessionInvalidate(compressionSession)
    }
}

extension VideoToolboxH264Encoder {
    private func configure(_ session: VTCompressionSession) throws {
        try setProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        try setProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        try setProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_AutoLevel)
        try setProperty(
            session,
            key: kVTCompressionPropertyKey_MaxKeyFrameInterval,
            value: configuration.keyFrameInterval as CFNumber
        )

        if let bitrate: Int = configuration.bitrate {
            try setProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: bitrate as CFNumber)
        }

        let prepareStatus: OSStatus = VTCompressionSessionPrepareToEncodeFrames(session)
        guard prepareStatus == noErr else {
            OSLogger.error("Failed to prepare H264 encoder. status=\(prepareStatus)")
            throw VideoDeviceError.videoEncodingFailed(status: prepareStatus)
        }
    }

    private func setProperty(_ session: VTCompressionSession, key: CFString, value: CFTypeRef) throws {
        let status: OSStatus = VTSessionSetProperty(session, key: key, value: value)
        guard status == noErr else {
            OSLogger.error("Failed to configure H264 encoder property. status=\(status)")
            throw VideoDeviceError.videoEncodingFailed(status: status)
        }
    }

    private func validate(frame: VideoFrame) throws {
        let width: Int = CVPixelBufferGetWidth(frame.pixelBuffer)
        let height: Int = CVPixelBufferGetHeight(frame.pixelBuffer)

        guard width == configuration.inputFormat.width, height == configuration.inputFormat.height else {
            OSLogger.error("Rejected video frame because dimensions do not match the H264 encoder configuration.")
            throw VideoDeviceError.unsupportedFormat
        }
    }

    private static func makePacket(sampleBuffer: CMSampleBuffer, sourceFormat: VideoFormat) throws -> VideoEncodedPacket {
        let payload: Data = try copyPayload(from: sampleBuffer)
        let isKeyFrame: Bool = isKeyFrame(sampleBuffer: sampleBuffer)
        let parameterSets: H264ParameterSets? = isKeyFrame ? try copyParameterSets(from: sampleBuffer) : nil

        return VideoEncodedPacket(
            payload: payload,
            presentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
            duration: CMSampleBufferGetDuration(sampleBuffer),
            sourceFormat: sourceFormat,
            isKeyFrame: isKeyFrame,
            parameterSets: parameterSets
        )
    }

    private static func copyPayload(from sampleBuffer: CMSampleBuffer) throws -> Data {
        guard let blockBuffer: CMBlockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            OSLogger.error("Encoded H264 sample buffer did not contain a block buffer.")
            throw VideoDeviceError.missingEncodedFrameData
        }

        let length: Int = CMBlockBufferGetDataLength(blockBuffer)
        var data: Data = Data(count: length)
        let status: OSStatus = data.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress: UnsafeMutableRawPointer = rawBuffer.baseAddress else {
                return kCMBlockBufferBadPointerParameterErr
            }

            return CMBlockBufferCopyDataBytes(
                blockBuffer,
                atOffset: 0,
                dataLength: length,
                destination: baseAddress
            )
        }

        guard status == noErr else {
            OSLogger.error("Failed to copy H264 encoded payload. status=\(status)")
            throw VideoDeviceError.videoEncodingFailed(status: status)
        }

        return data
    }

    private static func isKeyFrame(sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments: [[CFString: Any]] = CMSampleBufferGetSampleAttachmentsArray(
            sampleBuffer,
            createIfNecessary: false
        ) as? [[CFString: Any]],
            let firstAttachment: [CFString: Any] = attachments.first else {
            return true
        }

        let isNotSync: Bool = firstAttachment[kCMSampleAttachmentKey_NotSync] as? Bool ?? false
        return !isNotSync
    }

    private static func copyParameterSets(from sampleBuffer: CMSampleBuffer) throws -> H264ParameterSets? {
        guard let formatDescription: CMFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return nil
        }

        let sequenceParameterSet: Data = try copyParameterSet(formatDescription: formatDescription, index: 0)
        let pictureParameterSet: Data = try copyParameterSet(formatDescription: formatDescription, index: 1)
        return H264ParameterSets(
            sequenceParameterSet: sequenceParameterSet,
            pictureParameterSet: pictureParameterSet
        )
    }

    private static func copyParameterSet(formatDescription: CMFormatDescription, index: Int) throws -> Data {
        var parameterSetPointer: UnsafePointer<UInt8>?
        var parameterSetSize: Int = 0
        var parameterSetCount: Int = 0
        var nalUnitHeaderLength: Int32 = 0
        let status: OSStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
            formatDescription,
            parameterSetIndex: index,
            parameterSetPointerOut: &parameterSetPointer,
            parameterSetSizeOut: &parameterSetSize,
            parameterSetCountOut: &parameterSetCount,
            nalUnitHeaderLengthOut: &nalUnitHeaderLength
        )

        guard status == noErr, let parameterSetPointer else {
            OSLogger.error("Failed to copy H264 parameter set. status=\(status)")
            throw VideoDeviceError.videoEncodingFailed(status: status)
        }

        return Data(bytes: parameterSetPointer, count: parameterSetSize)
    }
}
