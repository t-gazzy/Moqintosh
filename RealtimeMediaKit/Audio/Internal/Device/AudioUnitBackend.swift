//
//  AudioUnitBackend.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/18.
//

import AudioToolbox
import Foundation

class AudioUnitBackend: InternalAudioBackend, AudioUnitComponentDescribing {
    var client: (any AudioBackendClient)?
    let configuration: AudioDeviceConfiguration

    private var audioUnit: AudioUnit?
    private var isRunning: Bool
    private let inputBus: AudioUnitElement
    private let outputBus: AudioUnitElement

    init(configuration: AudioDeviceConfiguration) {
        self.configuration = configuration
        self.isRunning = false
        self.inputBus = 1
        self.outputBus = 0
        OSLogger.debug(
            "Initialized audio unit backend. sampleRate=\(configuration.format.sampleRate) channels=\(configuration.format.channelCount) inputEnabled=\(configuration.inputEnabled) outputEnabled=\(configuration.outputEnabled)"
        )
    }

    var componentDescription: AudioComponentDescription {
        preconditionFailure("Subclasses must provide an AudioComponentDescription.")
    }

    func start() throws {
        guard !isRunning else {
            OSLogger.warn("Audio unit backend start was requested while already running.")
            throw AudioDeviceError.alreadyRunning
        }

        OSLogger.info("Starting audio unit backend.")
        try prepareAudioUnitIfNeeded()
        guard let audioUnit else {
            OSLogger.error("Audio unit backend could not start because the audio unit is missing after preparation.")
            throw AudioDeviceError.audioUnitCreationFailed
        }

        let status: OSStatus = AudioOutputUnitStart(audioUnit)
        guard status == noErr else {
            OSLogger.error("Failed to start audio unit backend. status=\(status)")
            throw AudioDeviceError.audioUnitStartFailed(status: status)
        }

        isRunning = true
        OSLogger.info("Audio unit backend started.")
    }

    func stop() throws {
        guard isRunning else {
            OSLogger.warn("Audio unit backend stop was requested while not running.")
            throw AudioDeviceError.notRunning
        }

        guard let audioUnit else {
            OSLogger.error("Audio unit backend could not stop because the audio unit is missing.")
            throw AudioDeviceError.audioUnitCreationFailed
        }

        let status: OSStatus = AudioOutputUnitStop(audioUnit)
        guard status == noErr else {
            OSLogger.error("Failed to stop audio unit backend. status=\(status)")
            throw AudioDeviceError.audioUnitStopFailed(status: status)
        }

        isRunning = false
        OSLogger.info("Audio unit backend stopped.")
    }

    private func prepareAudioUnitIfNeeded() throws {
        guard audioUnit == nil else {
            OSLogger.debug("Audio unit backend is already prepared.")
            return
        }

        var description: AudioComponentDescription = componentDescription
        guard let component: AudioComponent = AudioComponentFindNext(nil, &description) else {
            OSLogger.error("Failed to find audio component for audio unit backend.")
            throw AudioDeviceError.audioComponentNotFound
        }

        var audioUnit: AudioUnit?
        let status: OSStatus = AudioComponentInstanceNew(component, &audioUnit)
        guard status == noErr, let audioUnit else {
            OSLogger.error("Failed to create audio unit instance. status=\(status)")
            throw AudioDeviceError.audioUnitCreationFailed
        }

        OSLogger.debug("Configuring audio unit instance.")
        try configureAudioUnit(audioUnit)

        let initializeStatus: OSStatus = AudioUnitInitialize(audioUnit)
        guard initializeStatus == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            OSLogger.error("Failed to initialize audio unit instance. status=\(initializeStatus)")
            throw AudioDeviceError.audioUnitInitializationFailed(status: initializeStatus)
        }

        self.audioUnit = audioUnit
        OSLogger.info("Prepared audio unit backend.")
    }

    private func configureAudioUnit(_ audioUnit: AudioUnit) throws {
        try validateFormat()

        if configuration.inputEnabled {
            try setEnableIO(audioUnit, scope: kAudioUnitScope_Input, bus: inputBus, isEnabled: true)
            try setStreamFormat(audioUnit, scope: kAudioUnitScope_Output, bus: inputBus)
            try setInputCallback(audioUnit)
        }

        if configuration.outputEnabled {
            try setEnableIO(audioUnit, scope: kAudioUnitScope_Output, bus: outputBus, isEnabled: true)
            try setStreamFormat(audioUnit, scope: kAudioUnitScope_Input, bus: outputBus)
            try setRenderCallback(audioUnit)
        }
    }

    private func validateFormat() throws {
        guard configuration.format.bytesPerSample == MemoryLayout<Float>.size else {
            OSLogger.error("Unsupported audio format. bytesPerSample=\(configuration.format.bytesPerSample)")
            throw AudioDeviceError.unsupportedFormat
        }
    }

    private func setEnableIO(
        _ audioUnit: AudioUnit,
        scope: AudioUnitScope,
        bus: AudioUnitElement,
        isEnabled: Bool
    ) throws {
        var flag: UInt32 = isEnabled ? 1 : 0
        let status: OSStatus = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_EnableIO,
            scope,
            bus,
            &flag,
            UInt32(MemoryLayout<UInt32>.size)
        )

        guard status == noErr else {
            OSLogger.error("Failed to set enable I/O on audio unit. scope=\(scope) bus=\(bus) status=\(status)")
            throw AudioDeviceError.audioUnitConfigurationFailed(status: status)
        }
    }

    private func setStreamFormat(
        _ audioUnit: AudioUnit,
        scope: AudioUnitScope,
        bus: AudioUnitElement
    ) throws {
        var streamDescription: AudioStreamBasicDescription = makeStreamDescription()
        let status: OSStatus = AudioUnitSetProperty(
            audioUnit,
            kAudioUnitProperty_StreamFormat,
            scope,
            bus,
            &streamDescription,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        )

        guard status == noErr else {
            OSLogger.error("Failed to set stream format on audio unit. scope=\(scope) bus=\(bus) status=\(status)")
            throw AudioDeviceError.audioUnitConfigurationFailed(status: status)
        }
    }

    private func setInputCallback(_ audioUnit: AudioUnit) throws {
        var callbackStruct: AURenderCallbackStruct = AURenderCallbackStruct(
            inputProc: AudioUnitBackend.inputCallback,
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )
        let status: OSStatus = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_SetInputCallback,
            kAudioUnitScope_Global,
            inputBus,
            &callbackStruct,
            UInt32(MemoryLayout<AURenderCallbackStruct>.size)
        )

        guard status == noErr else {
            OSLogger.error("Failed to set input callback on audio unit. status=\(status)")
            throw AudioDeviceError.audioUnitConfigurationFailed(status: status)
        }
    }

    private func setRenderCallback(_ audioUnit: AudioUnit) throws {
        var callbackStruct: AURenderCallbackStruct = AURenderCallbackStruct(
            inputProc: AudioUnitBackend.renderCallback,
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )
        let status: OSStatus = AudioUnitSetProperty(
            audioUnit,
            kAudioUnitProperty_SetRenderCallback,
            kAudioUnitScope_Input,
            outputBus,
            &callbackStruct,
            UInt32(MemoryLayout<AURenderCallbackStruct>.size)
        )

        guard status == noErr else {
            OSLogger.error("Failed to set render callback on audio unit. status=\(status)")
            throw AudioDeviceError.audioUnitConfigurationFailed(status: status)
        }
    }

    private func makeStreamDescription() -> AudioStreamBasicDescription {
        let channelCount: UInt32 = UInt32(configuration.format.channelCount)
        let bitsPerChannel: UInt32 = UInt32(configuration.format.bytesPerSample * 8)
        let bytesPerFrame: UInt32 = UInt32(configuration.format.channelCount * configuration.format.bytesPerSample)

        return AudioStreamBasicDescription(
            mSampleRate: configuration.format.sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagsNativeEndian,
            mBytesPerPacket: bytesPerFrame,
            mFramesPerPacket: 1,
            mBytesPerFrame: bytesPerFrame,
            mChannelsPerFrame: channelCount,
            mBitsPerChannel: bitsPerChannel,
            mReserved: 0
        )
    }
}

extension AudioUnitBackend {
    private static let inputCallback: AURenderCallback = { reference, actionFlags, timeStamp, busNumber, frameCount, _ in
        let backend: AudioUnitBackend = Unmanaged<AudioUnitBackend>
            .fromOpaque(reference)
            .takeUnretainedValue()

        return backend.handleInput(
            actionFlags: actionFlags,
            timeStamp: timeStamp,
            busNumber: busNumber,
            frameCount: frameCount
        )
    }

    private static let renderCallback: AURenderCallback = { reference, actionFlags, timeStamp, busNumber, frameCount, ioData in
        let backend: AudioUnitBackend = Unmanaged<AudioUnitBackend>
            .fromOpaque(reference)
            .takeUnretainedValue()

        return backend.handleRender(
            actionFlags: actionFlags,
            timeStamp: timeStamp,
            busNumber: busNumber,
            frameCount: frameCount,
            ioData: ioData
        )
    }

    private func handleInput(
        actionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        timeStamp: UnsafePointer<AudioTimeStamp>,
        busNumber: UInt32,
        frameCount: UInt32
    ) -> OSStatus {
        guard configuration.inputEnabled, let audioUnit else {
            return noErr
        }

        var frame: AudioFrame = AudioFrame(
            format: configuration.format,
            frameCount: Int(frameCount)
        )
        var status: OSStatus = noErr

        frame.withUnsafeMutableSamplePointer { samplePointer in
            var bufferList: AudioBufferList = AudioBufferList(
                mNumberBuffers: 1,
                mBuffers: AudioBuffer(
                    mNumberChannels: UInt32(configuration.format.channelCount),
                    mDataByteSize: UInt32(frame.samples.count * MemoryLayout<Float>.size),
                    mData: samplePointer
                )
            )

            status = AudioUnitRender(
                audioUnit,
                actionFlags,
                timeStamp,
                busNumber,
                frameCount,
                &bufferList
            )
        }

        guard status == noErr else {
            OSLogger.error("AudioUnitRender failed in input callback. status=\(status)")
            return status
        }

        client?.audioBackend(self, didCapture: &frame)
        return noErr
    }

    private func handleRender(
        actionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        timeStamp: UnsafePointer<AudioTimeStamp>,
        busNumber: UInt32,
        frameCount: UInt32,
        ioData: UnsafeMutablePointer<AudioBufferList>?
    ) -> OSStatus {
        guard configuration.outputEnabled else {
            return noErr
        }

        guard let ioData else {
            return noErr
        }

        _ = actionFlags
        _ = timeStamp
        _ = busNumber

        var frame: AudioFrame = AudioFrame(
            format: configuration.format,
            frameCount: Int(frameCount)
        )
        client?.audioBackend(self, willRender: &frame)

        var audioBufferList: UnsafeMutableAudioBufferListPointer = UnsafeMutableAudioBufferListPointer(ioData)
        guard let buffer: UnsafeMutableAudioBufferListPointer.Element = audioBufferList.first else {
            return noErr
        }

        frame.withUnsafeSamplePointer { samplePointer in
            guard let destination: UnsafeMutableRawPointer = buffer.mData else {
                return
            }

            destination.copyMemory(
                from: samplePointer,
                byteCount: min(
                    Int(buffer.mDataByteSize),
                    frame.samples.count * MemoryLayout<Float>.size
                )
            )
        }

        return noErr
    }
}

extension AudioUnitBackend {
    deinit {
        guard let audioUnit else {
            return
        }

        OSLogger.debug("Disposing audio unit backend.")
        AudioUnitUninitialize(audioUnit)
        AudioComponentInstanceDispose(audioUnit)
    }
}
