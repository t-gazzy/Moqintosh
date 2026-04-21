//
//  AudioConverterOpusDecoder.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import AVFAudio
import Foundation

final class AudioConverterOpusDecoder: InternalAudioPacketDecoding {
    private let configuration: OpusDecoderConfiguration
    private let outputFormat: AudioFormat
    private let converter: AVAudioConverter

    init(configuration: OpusDecoderConfiguration) throws {
        self.configuration = configuration
        self.outputFormat = configuration.outputFormat

        OSLogger.debug(
            "Creating Opus audio decoder. sampleRate=\(outputFormat.sampleRate) channels=\(outputFormat.channelCount)"
        )

        guard let inputFormat: AVAudioFormat = Self.makeOpusFormat(configuration: configuration) else {
            OSLogger.error("Failed to create Opus decoder input format.")
            throw AudioDeviceError.unsupportedFormat
        }

        guard let outputFormat: AVAudioFormat = Self.makePCMFormat(format: configuration.outputFormat) else {
            OSLogger.error("Failed to create Opus decoder output format.")
            throw AudioDeviceError.unsupportedFormat
        }

        if let magicCookie: Data = configuration.magicCookie {
            inputFormat.magicCookie = magicCookie
        }

        guard let converter: AVAudioConverter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            OSLogger.error("Failed to create Opus audio decoder.")
            throw AudioDeviceError.audioDecodingFailed(status: -1)
        }

        self.converter = converter
        OSLogger.info("Created Opus audio decoder.")
    }

    func decode(_ packet: AudioEncodedPacket) throws -> AudioFrame {
        guard packet.sourceFormat == outputFormat else {
            OSLogger.error("Rejected Opus packet because format does not match the decoder configuration.")
            throw AudioDeviceError.unsupportedFormat
        }

        let compressedBuffer: AVAudioCompressedBuffer = AVAudioCompressedBuffer(
            format: converter.inputFormat,
            packetCapacity: 1,
            maximumPacketSize: packet.payload.count
        )

        packet.payload.withUnsafeBytes { payloadBuffer in
            guard let baseAddress: UnsafeRawPointer = payloadBuffer.baseAddress else {
                return
            }

            compressedBuffer.data.copyMemory(
                from: baseAddress,
                byteCount: packet.payload.count
            )
        }

        compressedBuffer.packetDescriptions?.pointee = AudioStreamPacketDescription(
            mStartOffset: 0,
            mVariableFramesInPacket: 0,
            mDataByteSize: UInt32(packet.payload.count)
        )
        compressedBuffer.packetCount = 1
        compressedBuffer.byteLength = UInt32(packet.payload.count)

        guard let outputBuffer: AVAudioPCMBuffer = AVAudioPCMBuffer(
            pcmFormat: converter.outputFormat,
            frameCapacity: AVAudioFrameCount(packet.frameCount)
        ) else {
            throw AudioDeviceError.unsupportedFormat
        }

        var conversionError: NSError?
        converter.convert(to: outputBuffer, error: &conversionError) { _, outputStatus in
            outputStatus.pointee = .haveData
            return compressedBuffer
        }

        if let conversionError {
            OSLogger.error("Failed to decode Opus packet: \(conversionError)")
            throw conversionError
        }

        return try makeAudioFrame(buffer: outputBuffer, frameCount: packet.frameCount)
    }

    deinit {
        OSLogger.debug("Disposing Opus audio decoder.")
    }
}

extension AudioConverterOpusDecoder {
    private func makeAudioFrame(buffer: AVAudioPCMBuffer, frameCount: Int) throws -> AudioFrame {
        guard let channelData: UnsafePointer<UnsafeMutablePointer<Float>> = buffer.floatChannelData else {
            throw AudioDeviceError.unsupportedFormat
        }

        let copiedFrameCount: Int = min(Int(buffer.frameLength), frameCount)
        var samples: ContiguousArray<Float> = ContiguousArray<Float>(
            repeating: 0.0,
            count: frameCount * outputFormat.channelCount
        )

        for channelIndex in 0 ..< outputFormat.channelCount {
            let source: UnsafeMutablePointer<Float> = channelData[channelIndex]

            for frameIndex in 0 ..< copiedFrameCount {
                let sampleIndex: Int = frameIndex * outputFormat.channelCount + channelIndex
                samples[sampleIndex] = source[frameIndex]
            }
        }

        return AudioFrame(format: outputFormat, frameCount: frameCount, samples: samples)
    }

    private static func makeOpusFormat(configuration: OpusDecoderConfiguration) -> AVAudioFormat? {
        var inputDescription: AudioStreamBasicDescription = AudioStreamBasicDescription(
            mSampleRate: configuration.outputFormat.sampleRate,
            mFormatID: kAudioFormatOpus,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: UInt32(configuration.frameCountPerPacket),
            mBytesPerFrame: 0,
            mChannelsPerFrame: UInt32(configuration.outputFormat.channelCount),
            mBitsPerChannel: 0,
            mReserved: 0
        )

        return AVAudioFormat(streamDescription: &inputDescription)
    }

    private static func makePCMFormat(format: AudioFormat) -> AVAudioFormat? {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: format.sampleRate,
            channels: AVAudioChannelCount(format.channelCount),
            interleaved: false
        )
    }
}
