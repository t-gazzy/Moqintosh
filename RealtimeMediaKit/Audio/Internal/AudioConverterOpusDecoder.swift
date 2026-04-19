//
//  AudioConverterOpusDecoder.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import AudioToolbox
import Foundation

final class AudioConverterOpusDecoder: InternalAudioPacketDecoding {
    private let outputFormat: AudioFormat
    private let converter: AudioConverterRef
    private var currentPacket: AudioEncodedPacket?
    private var didConsumeCurrentPacket: Bool
    private var currentPacketDescription: AudioStreamPacketDescription

    init(outputFormat: AudioFormat) throws {
        self.outputFormat = outputFormat
        self.didConsumeCurrentPacket = false
        self.currentPacketDescription = AudioStreamPacketDescription(
            mStartOffset: 0,
            mVariableFramesInPacket: 0,
            mDataByteSize: 0
        )

        OSLogger.debug(
            "Creating Opus audio decoder. sampleRate=\(outputFormat.sampleRate) channels=\(outputFormat.channelCount)"
        )

        var inputDescription: AudioStreamBasicDescription = Self.makeInputDescription(format: outputFormat)
        var outputDescription: AudioStreamBasicDescription = Self.makeOutputDescription(format: outputFormat)
        var converter: AudioConverterRef?
        let status: OSStatus = AudioConverterNew(&inputDescription, &outputDescription, &converter)

        guard status == noErr, let converter else {
            OSLogger.error("Failed to create Opus audio decoder. status=\(status)")
            throw AudioDeviceError.audioDecodingFailed(status: status)
        }

        self.converter = converter
        OSLogger.info("Created Opus audio decoder.")
    }

    func decode(_ packet: AudioEncodedPacket) throws -> AudioFrame {
        guard packet.sourceFormat == outputFormat else {
            OSLogger.error("Rejected Opus packet because format does not match the decoder configuration.")
            throw AudioDeviceError.unsupportedFormat
        }

        currentPacket = packet
        didConsumeCurrentPacket = false

        var outputFrame: AudioFrame = AudioFrame(format: outputFormat, frameCount: packet.frameCount)
        var ioOutputPacketSize: UInt32 = UInt32(packet.frameCount)
        var outputStatus: OSStatus = noErr

        outputFrame.withUnsafeMutableSamplePointer { samplePointer in
            var outputBufferList: AudioBufferList = AudioBufferList(
                mNumberBuffers: 1,
                mBuffers: AudioBuffer(
                    mNumberChannels: UInt32(outputFormat.channelCount),
                    mDataByteSize: UInt32(outputFrame.samples.count * MemoryLayout<Float>.size),
                    mData: samplePointer
                )
            )

            outputStatus = AudioConverterFillComplexBuffer(
                converter,
                Self.inputDataProc,
                Unmanaged.passUnretained(self).toOpaque(),
                &ioOutputPacketSize,
                &outputBufferList,
                nil
            )
        }

        currentPacket = nil
        didConsumeCurrentPacket = false

        guard outputStatus == noErr else {
            OSLogger.error("Failed to decode Opus packet. status=\(outputStatus)")
            throw AudioDeviceError.audioDecodingFailed(status: outputStatus)
        }

        return outputFrame
    }

    deinit {
        OSLogger.debug("Disposing Opus audio decoder.")
        AudioConverterDispose(converter)
    }
}

extension AudioConverterOpusDecoder {
    private static let inputDataProc: AudioConverterComplexInputDataProc = { _, ioNumberDataPackets, ioData, outDataPacketDescription, inputDataProcUserData in
        let decoder: AudioConverterOpusDecoder = Unmanaged<AudioConverterOpusDecoder>
            .fromOpaque(inputDataProcUserData!)
            .takeUnretainedValue()

        return decoder.provideInput(
            ioNumberDataPackets: ioNumberDataPackets,
            ioData: ioData,
            outDataPacketDescription: outDataPacketDescription
        )
    }

    private func provideInput(
        ioNumberDataPackets: UnsafeMutablePointer<UInt32>,
        ioData: UnsafeMutablePointer<AudioBufferList>,
        outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?
    ) -> OSStatus {
        guard let currentPacket, !didConsumeCurrentPacket else {
            ioNumberDataPackets.pointee = 0
            ioData.pointee.mNumberBuffers = 0
            return noErr
        }

        didConsumeCurrentPacket = true
        ioNumberDataPackets.pointee = 1
        ioData.pointee.mNumberBuffers = 1
        ioData.pointee.mBuffers.mNumberChannels = UInt32(outputFormat.channelCount)
        ioData.pointee.mBuffers.mDataByteSize = UInt32(currentPacket.payload.count)

        currentPacket.payload.withUnsafeBytes { payloadBuffer in
            ioData.pointee.mBuffers.mData = UnsafeMutableRawPointer(mutating: payloadBuffer.baseAddress)
        }

        if let outDataPacketDescription {
            currentPacketDescription = AudioStreamPacketDescription(
                mStartOffset: 0,
                mVariableFramesInPacket: UInt32(currentPacket.frameCount),
                mDataByteSize: UInt32(currentPacket.payload.count)
            )
            outDataPacketDescription.pointee = withUnsafeMutablePointer(to: &currentPacketDescription) { $0 }
        }

        return noErr
    }

    private static func makeInputDescription(format: AudioFormat) -> AudioStreamBasicDescription {
        AudioStreamBasicDescription(
            mSampleRate: format.sampleRate,
            mFormatID: kAudioFormatOpus,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: 0,
            mBytesPerFrame: 0,
            mChannelsPerFrame: UInt32(format.channelCount),
            mBitsPerChannel: 0,
            mReserved: 0
        )
    }

    private static func makeOutputDescription(format: AudioFormat) -> AudioStreamBasicDescription {
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
}
