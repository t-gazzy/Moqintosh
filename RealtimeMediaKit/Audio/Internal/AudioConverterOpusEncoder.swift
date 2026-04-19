//
//  AudioConverterOpusEncoder.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import AudioToolbox
import Foundation

final class AudioConverterOpusEncoder: InternalAudioFrameEncoding {
    private let configuration: OpusEncoderConfiguration
    private let converter: AudioConverterRef
    private let maximumPacketSize: UInt32
    private var currentInputFrame: AudioFrame?
    private var didConsumeCurrentInputFrame: Bool

    init(configuration: OpusEncoderConfiguration) throws {
        self.configuration = configuration
        self.didConsumeCurrentInputFrame = false

        OSLogger.debug(
            "Creating Opus audio converter. sampleRate=\(configuration.inputFormat.sampleRate) channels=\(configuration.inputFormat.channelCount) frameCountPerPacket=\(configuration.frameCountPerPacket)"
        )

        var inputDescription: AudioStreamBasicDescription = Self.makeInputDescription(format: configuration.inputFormat)
        var outputDescription: AudioStreamBasicDescription = Self.makeOutputDescription(configuration: configuration)
        var converter: AudioConverterRef?
        let status: OSStatus = AudioConverterNew(&inputDescription, &outputDescription, &converter)

        guard status == noErr, let converter else {
            OSLogger.error("Failed to create Opus audio converter. status=\(status)")
            throw AudioDeviceError.audioUnitConfigurationFailed(status: status)
        }

        self.converter = converter

        if let bitrate: Int = configuration.bitrate {
            var bitrateValue: UInt32 = UInt32(bitrate)
            let bitrateStatus: OSStatus = AudioConverterSetProperty(
                converter,
                kAudioConverterEncodeBitRate,
                UInt32(MemoryLayout<UInt32>.size),
                &bitrateValue
            )

            guard bitrateStatus == noErr else {
                AudioConverterDispose(converter)
                OSLogger.error("Failed to configure Opus bitrate. status=\(bitrateStatus)")
                throw AudioDeviceError.audioUnitConfigurationFailed(status: bitrateStatus)
            }
        }

        var packetSize: UInt32 = 0
        var packetSizePropertySize: UInt32 = UInt32(MemoryLayout<UInt32>.size)
        let packetSizeStatus: OSStatus = AudioConverterGetProperty(
            converter,
            kAudioConverterPropertyMaximumOutputPacketSize,
            &packetSizePropertySize,
            &packetSize
        )

        guard packetSizeStatus == noErr else {
            AudioConverterDispose(converter)
            OSLogger.error("Failed to query Opus maximum packet size. status=\(packetSizeStatus)")
            throw AudioDeviceError.audioUnitConfigurationFailed(status: packetSizeStatus)
        }

        self.maximumPacketSize = packetSize
        OSLogger.info("Created Opus audio converter. maximumPacketSize=\(packetSize)")
    }

    func encode(_ frame: AudioFrame) throws -> AudioEncodedPacket {
        guard frame.format == configuration.inputFormat else {
            OSLogger.error("Rejected audio frame because format does not match the Opus encoder configuration.")
            throw AudioDeviceError.unsupportedFormat
        }

        guard frame.frameCount == configuration.frameCountPerPacket else {
            OSLogger.error("Rejected audio frame because frame count does not match the Opus encoder configuration.")
            throw AudioDeviceError.unsupportedFormat
        }

        currentInputFrame = frame
        didConsumeCurrentInputFrame = false

        var outputPacketCount: UInt32 = 1
        var outputPacketDescription: AudioStreamPacketDescription = AudioStreamPacketDescription(
            mStartOffset: 0,
            mVariableFramesInPacket: 0,
            mDataByteSize: 0
        )
        var outputPayload: Data = Data(count: Int(maximumPacketSize))

        let status: OSStatus = outputPayload.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress: UnsafeMutableRawPointer = rawBuffer.baseAddress else {
                return kAudio_ParamError
            }

            var outputBufferList: AudioBufferList = AudioBufferList(
                mNumberBuffers: 1,
                mBuffers: AudioBuffer(
                    mNumberChannels: UInt32(configuration.inputFormat.channelCount),
                    mDataByteSize: maximumPacketSize,
                    mData: baseAddress
                )
            )

            return AudioConverterFillComplexBuffer(
                converter,
                Self.inputDataProc,
                Unmanaged.passUnretained(self).toOpaque(),
                &outputPacketCount,
                &outputBufferList,
                &outputPacketDescription
            )
        }

        currentInputFrame = nil
        didConsumeCurrentInputFrame = false

        guard status == noErr else {
            OSLogger.error("Failed to encode Opus packet. status=\(status)")
            throw AudioDeviceError.audioUnitConfigurationFailed(status: status)
        }

        let encodedByteCount: Int = Int(outputPacketDescription.mDataByteSize)
        let payload: Data = outputPayload.prefix(encodedByteCount)

        return AudioEncodedPacket(
            payload: payload,
            frameCount: frame.frameCount,
            sourceFormat: frame.format
        )
    }

    deinit {
        OSLogger.debug("Disposing Opus audio converter.")
        AudioConverterDispose(converter)
    }
}

extension AudioConverterOpusEncoder {
    private static let inputDataProc: AudioConverterComplexInputDataProc = { converter, ioNumberDataPackets, ioData, _, inputDataProcUserData in
        let encoder: AudioConverterOpusEncoder = Unmanaged<AudioConverterOpusEncoder>
            .fromOpaque(inputDataProcUserData!)
            .takeUnretainedValue()

        return encoder.provideInput(
            converter: converter,
            ioNumberDataPackets: ioNumberDataPackets,
            ioData: ioData
        )
    }

    private func provideInput(
        converter: AudioConverterRef,
        ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
        ioData: UnsafeMutablePointer<AudioBufferList>
    ) -> OSStatus {
        _ = converter

        guard let currentInputFrame, !didConsumeCurrentInputFrame else {
            ioNumberDataPackets.pointee = 0
            ioData.pointee.mNumberBuffers = 0
            return noErr
        }

        didConsumeCurrentInputFrame = true

        currentInputFrame.withUnsafeSamplePointer { samplePointer in
            ioNumberDataPackets.pointee = 1
            ioData.pointee.mNumberBuffers = 1
            ioData.pointee.mBuffers.mNumberChannels = UInt32(currentInputFrame.format.channelCount)
            ioData.pointee.mBuffers.mDataByteSize = UInt32(currentInputFrame.samples.count * MemoryLayout<Float>.size)
            ioData.pointee.mBuffers.mData = UnsafeMutableRawPointer(mutating: samplePointer)
        }

        return noErr
    }

    private static func makeInputDescription(format: AudioFormat) -> AudioStreamBasicDescription {
        let bytesPerFrame: UInt32 = UInt32(format.channelCount * format.bytesPerSample)

        return AudioStreamBasicDescription(
            mSampleRate: format.sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian,
            mBytesPerPacket: bytesPerFrame,
            mFramesPerPacket: 1,
            mBytesPerFrame: bytesPerFrame,
            mChannelsPerFrame: UInt32(format.channelCount),
            mBitsPerChannel: UInt32(format.bytesPerSample * 8),
            mReserved: 0
        )
    }

    private static func makeOutputDescription(configuration: OpusEncoderConfiguration) -> AudioStreamBasicDescription {
        AudioStreamBasicDescription(
            mSampleRate: configuration.inputFormat.sampleRate,
            mFormatID: kAudioFormatOpus,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: UInt32(configuration.frameCountPerPacket),
            mBytesPerFrame: 0,
            mChannelsPerFrame: UInt32(configuration.inputFormat.channelCount),
            mBitsPerChannel: 0,
            mReserved: 0
        )
    }
}
