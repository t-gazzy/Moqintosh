//
//  AudioPlaybackBuffer.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import Foundation
import Synchronization

// Safe because access to the mutable sample store is serialized by Mutex.
public final class AudioPlaybackBuffer: @unchecked Sendable, AudioFrameSource {
    private struct State {
        var samples: ContiguousArray<Float>

        init(samples: ContiguousArray<Float> = ContiguousArray<Float>()) {
            self.samples = samples
        }
    }

    private let format: AudioFormat
    private let state: Mutex<State>

    public init(format: AudioFormat) {
        self.format = format
        self.state = Mutex<State>(State())
    }

    public func append(_ frame: AudioFrame) {
        guard frame.format == format else {
            OSLogger.error("Rejected playback frame because format does not match the playback buffer.")
            return
        }

        state.withLock { state in
            state.samples.append(contentsOf: frame.samples)
        }
    }

    public func render(into frame: inout AudioFrame) {
        guard frame.format == format else {
            OSLogger.error("Rejected render request because format does not match the playback buffer.")
            return
        }

        state.withLock { state in
            let requestedSampleCount: Int = frame.frameCount * frame.format.channelCount
            let availableSampleCount: Int = min(requestedSampleCount, state.samples.count)

            frame.withUnsafeMutableSamplePointer { destinationBaseAddress in
                state.samples.withUnsafeBufferPointer { sourceBuffer in
                    guard let sourceBaseAddress: UnsafePointer<Float> = sourceBuffer.baseAddress else {
                        return
                    }

                    destinationBaseAddress.initialize(repeating: 0.0, count: requestedSampleCount)
                    destinationBaseAddress.update(from: sourceBaseAddress, count: availableSampleCount)
                }
            }

            if availableSampleCount > 0 {
                state.samples.removeFirst(availableSampleCount)
            }
        }
    }
}
