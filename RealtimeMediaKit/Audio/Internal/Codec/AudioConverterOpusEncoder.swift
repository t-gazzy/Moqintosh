//
//  AudioConverterOpusEncoder.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import AVFAudio
import Foundation

final class AudioConverterOpusEncoder: InternalAudioFrameEncoding {
    private let configuration: OpusEncoderConfiguration
    private let converter: AVAudioConverter
    private let inputFormat: AVAudioFormat

    var magicCookie: Data? {
        converter.magicCookie
    }

    init(configuration: OpusEncoderConfiguration) throws {
        self.configuration = configuration

        OSLogger.debug(
            "Creating Opus audio converter. sampleRate=\(configuration.inputFormat.sampleRate) channels=\(configuration.inputFormat.channelCount) frameCountPerPacket=\(configuration.frameCountPerPacket)"
        )

        guard let inputFormat: AVAudioFormat = Self.makePCMFormat(format: configuration.inputFormat) else {
            OSLogger.error("Failed to create Opus encoder input format.")
            throw AudioDeviceError.unsupportedFormat
        }

        guard let outputFormat: AVAudioFormat = Self.makeOpusFormat(configuration: configuration) else {
            OSLogger.error("Failed to create Opus encoder output format.")
            throw AudioDeviceError.unsupportedFormat
        }

        guard let converter: AVAudioConverter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            OSLogger.error("Failed to create Opus audio converter.")
            throw AudioDeviceError.audioEncodingFailed(status: -1)
        }

        if let bitrate: Int = configuration.bitrate {
            converter.bitRate = bitrate
        }

        self.inputFormat = inputFormat
        self.converter = converter
        OSLogger.info("Created Opus audio converter.")
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

        let inputBuffer: AVAudioPCMBuffer = try makeInputBuffer(frame: frame)
        let compressedBuffer: AVAudioCompressedBuffer = AVAudioCompressedBuffer(
            format: converter.outputFormat,
            packetCapacity: 1,
            maximumPacketSize: 1_275
        )
        var conversionError: NSError?

        converter.convert(to: compressedBuffer, error: &conversionError) { _, outputStatus in
            outputStatus.pointee = .haveData
            return inputBuffer
        }

        if let conversionError {
            OSLogger.error("Failed to encode Opus packet: \(conversionError)")
            throw conversionError
        }

        let payload: Data = Data(
            bytes: compressedBuffer.data,
            count: Int(compressedBuffer.byteLength)
        )

        return AudioEncodedPacket(
            payload: payload,
            frameCount: frame.frameCount,
            sourceFormat: frame.format
        )
    }

    deinit {
        OSLogger.debug("Disposing Opus audio converter.")
    }
}

extension AudioConverterOpusEncoder {
    private func makeInputBuffer(frame: AudioFrame) throws -> AVAudioPCMBuffer {
        guard let buffer: AVAudioPCMBuffer = AVAudioPCMBuffer(
            pcmFormat: inputFormat,
            frameCapacity: AVAudioFrameCount(frame.frameCount)
        ) else {
            throw AudioDeviceError.unsupportedFormat
        }

        buffer.frameLength = AVAudioFrameCount(frame.frameCount)

        guard let channelData: UnsafePointer<UnsafeMutablePointer<Float>> = buffer.floatChannelData else {
            throw AudioDeviceError.unsupportedFormat
        }

        for channelIndex in 0 ..< frame.format.channelCount {
            let destination: UnsafeMutablePointer<Float> = channelData[channelIndex]

            for frameIndex in 0 ..< frame.frameCount {
                let sampleIndex: Int = frameIndex * frame.format.channelCount + channelIndex
                destination[frameIndex] = frame.samples[sampleIndex]
            }
        }

        return buffer
    }

    private static func makePCMFormat(format: AudioFormat) -> AVAudioFormat? {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: format.sampleRate,
            channels: AVAudioChannelCount(format.channelCount),
            interleaved: false
        )
    }

    private static func makeOpusFormat(configuration: OpusEncoderConfiguration) -> AVAudioFormat? {
        var outputDescription: AudioStreamBasicDescription = AudioStreamBasicDescription(
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

        return AVAudioFormat(streamDescription: &outputDescription)
    }
}
