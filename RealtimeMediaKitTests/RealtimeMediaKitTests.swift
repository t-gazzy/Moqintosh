//
//  RealtimeMediaKitTests.swift
//  RealtimeMediaKitTests
//
//  Created by Takemasa Kaji on 2026/04/18.
//

import AVFAudio
import Foundation
import Testing
@testable import RealtimeMediaKit

private final class BundleToken {}

struct RealtimeMediaKitTests {

    private let audioFormat: AudioFormat
    private let frameCountPerPacket: Int

    init() {
        self.audioFormat = AudioFormat(
            sampleRate: 48_000,
            channelCount: 1,
            bytesPerSample: MemoryLayout<Float>.size
        )
        self.frameCountPerPacket = 960
    }

    @Test func encodeHarvardSpeechToOpusFile() async throws {
        let outputURL: URL = try encodeHarvardSpeechToOpusFileIfNeeded(shouldOverwrite: true)
        let attributes: [FileAttributeKey: Any] = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize: UInt64 = try #require(attributes[.size] as? UInt64)

        #expect(fileSize > 0)
    }

    @Test func decodeHarvardSpeechOpusToWavFile() async throws {
        let outputURL: URL = try encodeHarvardSpeechToOpusFileIfNeeded(shouldOverwrite: true)
        let packetStream: OpusPacketStream = try readOpusPacketStream(from: outputURL)
        let decoder: OpusAudioDecoder = try OpusAudioDecoder(
            configuration: OpusDecoderConfiguration(
                outputFormat: audioFormat,
                frameCountPerPacket: frameCountPerPacket,
                magicCookie: packetStream.magicCookie
            )
        )
        let decodedOutputURL: URL = decodedWavOutputURL()
        var decodedPacketCount: Int = 0
        var nonSilentSampleCount: Int = 0

        // File output is deterministic in tests, unlike AudioSession playback which depends on device routing.
        let outputFile: AVAudioFile = try AVAudioFile(
            forWriting: decodedOutputURL,
            settings: wavOutputSettings()
        )

        for packet in packetStream.packets {
            let decodedFrame: AudioFrame = try decoder.decode(packet)
            try write(decodedFrame, to: outputFile)
            nonSilentSampleCount += decodedFrame.samples.filter { abs($0) > 0.000_001 }.count

            decodedPacketCount += 1
        }

        #expect(decodedPacketCount > 0)
        #expect(nonSilentSampleCount > 0)

        let attributes: [FileAttributeKey: Any] = try FileManager.default.attributesOfItem(atPath: decodedOutputURL.path)
        let fileSize: UInt64 = try #require(attributes[.size] as? UInt64)
        #expect(fileSize > 0)
    }

    private func encodeHarvardSpeechToOpusFileIfNeeded(shouldOverwrite: Bool) throws -> URL {
        let outputURL: URL = opusOutputURL()

        if !shouldOverwrite, FileManager.default.fileExists(atPath: outputURL.path) {
            return outputURL
        }

        let frames: [AudioFrame] = try loadHarvardSpeechFrames()
        let encoderConfiguration: OpusEncoderConfiguration = OpusEncoderConfiguration(
            inputFormat: audioFormat,
            frameCountPerPacket: frameCountPerPacket,
            bitrate: 32_000
        )
        let encoder: OpusAudioEncoder = try OpusAudioEncoder(configuration: encoderConfiguration)
        var outputData: Data = Data()

        for frame in frames {
            let packet: AudioEncodedPacket = try encoder.encode(frame)
            if outputData.isEmpty {
                let magicCookie: Data = encoder.magicCookie ?? Data()
                append(UInt32(magicCookie.count), to: &outputData)
                outputData.append(magicCookie)
            }

            append(UInt32(packet.frameCount), to: &outputData)
            append(UInt32(packet.payload.count), to: &outputData)
            outputData.append(packet.payload)
        }

        try outputData.write(to: outputURL, options: .atomic)
        return outputURL
    }

    private func loadHarvardSpeechFrames() throws -> [AudioFrame] {
        let inputURL: URL = try harvardSpeechURL()
        let inputFile: AVAudioFile = try AVAudioFile(forReading: inputURL)

        guard let targetFormat: AVAudioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: audioFormat.sampleRate,
            channels: AVAudioChannelCount(audioFormat.channelCount),
            interleaved: false
        ) else {
            throw TestError.failedToCreateAudioFormat
        }

        guard let converter: AVAudioConverter = AVAudioConverter(
            from: inputFile.processingFormat,
            to: targetFormat
        ) else {
            throw TestError.failedToCreateAudioConverter
        }

        let inputFrameCapacity: AVAudioFrameCount = AVAudioFrameCount(inputFile.length)
        guard let inputBuffer: AVAudioPCMBuffer = AVAudioPCMBuffer(
            pcmFormat: inputFile.processingFormat,
            frameCapacity: inputFrameCapacity
        ) else {
            throw TestError.failedToCreateAudioBuffer
        }

        try inputFile.read(into: inputBuffer)

        let sampleRateRatio: Double = audioFormat.sampleRate / inputFile.processingFormat.sampleRate
        let outputFrameCapacity: AVAudioFrameCount = AVAudioFrameCount(
            Double(inputBuffer.frameLength) * sampleRateRatio
        ) + AVAudioFrameCount(frameCountPerPacket)

        guard let outputBuffer: AVAudioPCMBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: outputFrameCapacity
        ) else {
            throw TestError.failedToCreateAudioBuffer
        }

        var didProvideInput: Bool = false
        var conversionError: NSError?
        let conversionStatus: AVAudioConverterOutputStatus = converter.convert(
            to: outputBuffer,
            error: &conversionError
        ) { _, outputStatus in
            if didProvideInput {
                outputStatus.pointee = .noDataNow
                return nil
            }

            didProvideInput = true
            outputStatus.pointee = .haveData
            return inputBuffer
        }

        if let conversionError {
            throw conversionError
        }

        guard conversionStatus == .haveData || conversionStatus == .inputRanDry || conversionStatus == .endOfStream else {
            throw TestError.failedToConvertAudio
        }

        guard let channelData: UnsafePointer<UnsafeMutablePointer<Float>> = outputBuffer.floatChannelData else {
            throw TestError.failedToReadAudioSamples
        }

        let samples: UnsafeMutablePointer<Float> = channelData[0]
        let sampleCount: Int = Int(outputBuffer.frameLength)
        var frames: [AudioFrame] = []
        var sampleOffset: Int = 0

        while sampleOffset < sampleCount {
            let remainingSampleCount: Int = sampleCount - sampleOffset
            let copiedSampleCount: Int = min(frameCountPerPacket, remainingSampleCount)
            var frameSamples: ContiguousArray<Float> = ContiguousArray<Float>(
                repeating: 0.0,
                count: frameCountPerPacket * audioFormat.channelCount
            )

            frameSamples.withUnsafeMutableBufferPointer { destinationBuffer in
                guard let destinationBaseAddress: UnsafeMutablePointer<Float> = destinationBuffer.baseAddress else {
                    return
                }

                destinationBaseAddress.update(
                    from: samples.advanced(by: sampleOffset),
                    count: copiedSampleCount
                )
            }

            frames.append(
                AudioFrame(
                    format: audioFormat,
                    frameCount: frameCountPerPacket,
                    samples: frameSamples
                )
            )
            sampleOffset += copiedSampleCount
        }

        return frames
    }

    private func readOpusPacketStream(from url: URL) throws -> OpusPacketStream {
        let data: Data = try Data(contentsOf: url)
        var offset: Int = 0
        var packets: [AudioEncodedPacket] = []
        let magicCookieByteCount: UInt32 = try readUInt32(from: data, offset: &offset)
        let magicCookieEndOffset: Int = offset + Int(magicCookieByteCount)

        guard magicCookieEndOffset <= data.count else {
            throw TestError.invalidOpusPacketFile
        }

        let magicCookie: Data? = magicCookieByteCount == 0 ? nil : data.subdata(in: offset ..< magicCookieEndOffset)
        offset = magicCookieEndOffset

        while offset < data.count {
            let frameCount: UInt32 = try readUInt32(from: data, offset: &offset)
            let payloadByteCount: UInt32 = try readUInt32(from: data, offset: &offset)
            let payloadEndOffset: Int = offset + Int(payloadByteCount)

            guard payloadEndOffset <= data.count else {
                throw TestError.invalidOpusPacketFile
            }

            let payload: Data = data.subdata(in: offset ..< payloadEndOffset)
            packets.append(
                AudioEncodedPacket(
                    payload: payload,
                    frameCount: Int(frameCount),
                    sourceFormat: audioFormat
                )
            )
            offset = payloadEndOffset
        }

        #expect(!packets.isEmpty)
        return OpusPacketStream(magicCookie: magicCookie, packets: packets)
    }

    private func append(_ value: UInt32, to data: inout Data) {
        var littleEndianValue: UInt32 = value.littleEndian
        withUnsafeBytes(of: &littleEndianValue) { valueBuffer in
            data.append(contentsOf: valueBuffer)
        }
    }

    private func readUInt32(from data: Data, offset: inout Int) throws -> UInt32 {
        let endOffset: Int = offset + MemoryLayout<UInt32>.size

        guard endOffset <= data.count else {
            throw TestError.invalidOpusPacketFile
        }

        let value: UInt32 = data[offset ..< endOffset].enumerated().reduce(UInt32(0)) { partialResult, element in
            let shift: UInt32 = UInt32(element.offset * 8)
            return partialResult | (UInt32(element.element) << shift)
        }
        offset = endOffset
        return value
    }

    private func write(_ frame: AudioFrame, to file: AVAudioFile) throws {
        guard let format: AVAudioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: frame.format.sampleRate,
            channels: AVAudioChannelCount(frame.format.channelCount),
            interleaved: false
        ) else {
            throw TestError.failedToCreateAudioFormat
        }

        guard let buffer: AVAudioPCMBuffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(frame.frameCount)
        ) else {
            throw TestError.failedToCreateAudioBuffer
        }

        buffer.frameLength = AVAudioFrameCount(frame.frameCount)

        guard let channelData: UnsafePointer<UnsafeMutablePointer<Float>> = buffer.floatChannelData else {
            throw TestError.failedToReadAudioSamples
        }

        frame.samples.withUnsafeBufferPointer { sourceBuffer in
            guard let sourceBaseAddress: UnsafePointer<Float> = sourceBuffer.baseAddress else {
                return
            }

            channelData[0].update(
                from: sourceBaseAddress,
                count: frame.frameCount
            )
        }

        try file.write(from: buffer)
    }

    private func wavOutputSettings() -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: audioFormat.sampleRate,
            AVNumberOfChannelsKey: audioFormat.channelCount,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
    }

    private func harvardSpeechURL() throws -> URL {
        guard let url: URL = Bundle(for: BundleToken.self).url(
            forResource: "Harvard_speech100",
            withExtension: "wav"
        ) else {
            throw TestError.missingHarvardSpeechResource
        }

        return url
    }

    private func opusOutputURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Harvard_speech100.raw-opus")
    }

    private func decodedWavOutputURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Harvard_speech100_decoded.wav")
    }
}

private enum TestError: Error {
    case failedToCreateAudioFormat
    case failedToCreateAudioConverter
    case failedToCreateAudioBuffer
    case failedToConvertAudio
    case failedToReadAudioSamples
    case invalidOpusPacketFile
    case missingHarvardSpeechResource
}

private struct OpusPacketStream {
    let magicCookie: Data?
    let packets: [AudioEncodedPacket]
}
