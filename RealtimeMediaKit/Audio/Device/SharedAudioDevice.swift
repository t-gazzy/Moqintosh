//
//  SharedAudioDevice.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation
import Synchronization

// Safe because lifecycle state is serialized by state and the shared device is not exposed mutably.
public final class SharedAudioDevice: @unchecked Sendable {
    public static let shared: SharedAudioDevice = SharedAudioDevice()

    private struct State {
        var device: SystemAudioDevice?
        var playbackBuffer: AudioPlaybackBuffer?
        var activeFormat: AudioFormat?
        var isDeviceRunning: Bool
        var playbackClientCount: Int
        var activeCaptureSinkIdentifier: ObjectIdentifier?

        init() {
            self.device = nil
            self.playbackBuffer = nil
            self.activeFormat = nil
            self.isDeviceRunning = false
            self.playbackClientCount = 0
            self.activeCaptureSinkIdentifier = nil
        }
    }

    private let sessionController: SystemAudioSessionController
    private let state: Mutex<State>

    init(sessionController: SystemAudioSessionController = SystemAudioSessionController()) {
        self.sessionController = sessionController
        self.state = Mutex<State>(State())
    }

    func startCapture(
        format: AudioFormat,
        encoder: any AudioFrameEncoder,
        sink: any AudioEncodedPacketSink,
        errorHandler: @escaping @Sendable (Error) -> Void
    ) throws {
        try state.withLock { state in
            let device: SystemAudioDevice = try makeDeviceIfNeeded(format: format, state: &state)
            let sinkIdentifier: ObjectIdentifier = ObjectIdentifier(sink)

            if let activeCaptureSinkIdentifier: ObjectIdentifier = state.activeCaptureSinkIdentifier,
               activeCaptureSinkIdentifier != sinkIdentifier {
                throw AudioDeviceError.alreadyRunning
            }

            device.pipeline.removeAllProcessors()
            device.pipeline.appendProcessor(
                AudioEncodingProcessor(
                    encoder: encoder,
                    sink: sink,
                    errorHandler: errorHandler
                )
            )
            state.activeCaptureSinkIdentifier = sinkIdentifier

            if !state.isDeviceRunning {
                try sessionController.activateForCaptureAndPlayback()
                try device.start()
                state.isDeviceRunning = true
            }
        }
    }

    func stopCapture(sink: any AudioEncodedPacketSink) {
        do {
            try state.withLock { state in
                let sinkIdentifier: ObjectIdentifier = ObjectIdentifier(sink)
                guard state.activeCaptureSinkIdentifier == sinkIdentifier else {
                    return
                }

                state.device?.pipeline.removeAllProcessors()
                state.activeCaptureSinkIdentifier = nil
                try stopDeviceIfIdle(state: &state)
            }
        } catch {
            OSLogger.error("Failed to stop shared audio capture: \(String(describing: error))")
        }
    }

    public func acquirePlaybackBuffer(format: AudioFormat) throws -> AudioPlaybackBuffer {
        try state.withLock { state in
            let device: SystemAudioDevice = try makeDeviceIfNeeded(format: format, state: &state)
            guard let playbackBuffer: AudioPlaybackBuffer = state.playbackBuffer else {
                preconditionFailure("Shared audio playback buffer must be available after device creation.")
            }

            state.playbackClientCount += 1
            if !state.isDeviceRunning {
                try sessionController.activateForCaptureAndPlayback()
                try device.start()
                state.isDeviceRunning = true
            }

            return playbackBuffer
        }
    }

    public func releasePlayback() {
        do {
            try state.withLock { state in
                if state.playbackClientCount > 0 {
                    state.playbackClientCount -= 1
                }
                try stopDeviceIfIdle(state: &state)
            }
        } catch {
            OSLogger.error("Failed to release shared audio playback: \(String(describing: error))")
        }
    }
}

extension SharedAudioDevice {
    private func makeDeviceIfNeeded(
        format: AudioFormat,
        state: inout State
    ) throws -> SystemAudioDevice {
        if let activeFormat: AudioFormat = state.activeFormat, activeFormat != format {
            throw AudioDeviceError.unsupportedFormat
        }

        if let device: SystemAudioDevice = state.device {
            return device
        }

        try sessionController.activateForCaptureAndPlayback()
        let device: SystemAudioDevice = try SystemAudioDevice(
            configuration: AudioDeviceConfiguration(
                format: format,
                backend: .voiceProcessingIO,
                inputProcessing: .voiceProcessed,
                inputEnabled: true,
                outputEnabled: true
            )
        )
        let playbackBuffer: AudioPlaybackBuffer = AudioPlaybackBuffer(format: format)
        device.renderSource = playbackBuffer

        state.device = device
        state.playbackBuffer = playbackBuffer
        state.activeFormat = format
        return device
    }

    private func stopDeviceIfIdle(state: inout State) throws {
        guard state.isDeviceRunning else {
            return
        }
        guard state.activeCaptureSinkIdentifier == nil, state.playbackClientCount == 0 else {
            return
        }
        try state.device?.stop()
        state.isDeviceRunning = false
        try sessionController.deactivate()
    }
}
