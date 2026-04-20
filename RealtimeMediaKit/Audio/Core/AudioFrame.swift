//
//  AudioFrame.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation

public struct AudioFrame: Sendable {
    public let format: AudioFormat
    public let frameCount: Int
    public private(set) var samples: ContiguousArray<Float>

    public init(format: AudioFormat, frameCount: Int) {
        let sampleCount: Int = frameCount * format.channelCount
        self.format = format
        self.frameCount = frameCount
        self.samples = ContiguousArray<Float>(repeating: 0.0, count: sampleCount)
    }

    public init(format: AudioFormat, frameCount: Int, samples: ContiguousArray<Float>) {
        let expectedSampleCount: Int = frameCount * format.channelCount
        precondition(
            samples.count == expectedSampleCount,
            "AudioFrame samples must match frameCount * channelCount."
        )

        self.format = format
        self.frameCount = frameCount
        self.samples = samples
    }

    mutating func withUnsafeMutableSamplePointer<Result>(
        _ body: (UnsafeMutablePointer<Float>) throws -> Result
    ) rethrows -> Result {
        try samples.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress: UnsafeMutablePointer<Float> = buffer.baseAddress else {
                preconditionFailure("AudioFrame samples must be allocated.")
            }

            return try body(baseAddress)
        }
    }

    func withUnsafeSamplePointer<Result>(
        _ body: (UnsafePointer<Float>) throws -> Result
    ) rethrows -> Result {
        try samples.withUnsafeBufferPointer { buffer in
            guard let baseAddress: UnsafePointer<Float> = buffer.baseAddress else {
                preconditionFailure("AudioFrame samples must be allocated.")
            }

            return try body(baseAddress)
        }
    }
}
