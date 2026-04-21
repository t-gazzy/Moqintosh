//
//  CameraVideoSource.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

public final class CameraVideoSource: NSObject, VideoSource {
    public let configuration: CameraVideoConfiguration
    public let frames: AsyncThrowingStream<VideoFrame, Error>

    private let captureSession: AVCaptureSession
    private let videoOutput: AVCaptureVideoDataOutput
    private let sessionQueue: DispatchQueue
    private let outputQueue: DispatchQueue
    private let frameContinuation: AsyncThrowingStream<VideoFrame, Error>.Continuation
    private var isRunning: Bool

    public init(configuration: CameraVideoConfiguration) throws {
        var capturedContinuation: AsyncThrowingStream<VideoFrame, Error>.Continuation?
        self.configuration = configuration
        self.captureSession = AVCaptureSession()
        self.videoOutput = AVCaptureVideoDataOutput()
        self.sessionQueue = DispatchQueue(label: "RealtimeMediaKit.CameraVideoSource.Session")
        self.outputQueue = DispatchQueue(label: "RealtimeMediaKit.CameraVideoSource.Output")
        self.frames = AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            capturedContinuation = continuation
        }

        guard let capturedContinuation else {
            preconditionFailure("Camera video frame stream continuation must be created during initialization.")
        }

        self.frameContinuation = capturedContinuation
        self.isRunning = false
        super.init()

        try configureCaptureSession()
    }

    public static func requestAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { isGranted in
                continuation.resume(returning: isGranted)
            }
        }
    }

    public func start() async throws {
        guard !isRunning else {
            OSLogger.warn("Camera video source start was requested while already running.")
            throw VideoDeviceError.alreadyRunning
        }

        guard Self.authorizationAllowsCapture else {
            OSLogger.error("Camera video source could not start because camera access is denied.")
            throw VideoDeviceError.cameraAccessDenied
        }

        try await runOnSessionQueue {
            OSLogger.info("Starting camera video source.")
            self.captureSession.startRunning()
            self.isRunning = true
            OSLogger.info("Camera video source started.")
        }
    }

    public func stop() async throws {
        guard isRunning else {
            OSLogger.warn("Camera video source stop was requested while not running.")
            throw VideoDeviceError.notRunning
        }

        try await runOnSessionQueue {
            OSLogger.info("Stopping camera video source.")
            self.captureSession.stopRunning()
            self.isRunning = false
            OSLogger.info("Camera video source stopped.")
        }
    }

    deinit {
        frameContinuation.finish()
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
        captureSession.stopRunning()
    }
}

extension CameraVideoSource: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            OSLogger.warn("Dropped camera sample because it did not contain a pixel buffer.")
            return
        }

        let frame: VideoFrame = VideoFrame(
            pixelBuffer: pixelBuffer,
            presentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
            duration: CMSampleBufferGetDuration(sampleBuffer)
        )
        frameContinuation.yield(frame)
    }
}

extension CameraVideoSource {
    private static var authorizationAllowsCapture: Bool {
        let status: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        return status == .authorized || status == .notDetermined
    }

    private func configureCaptureSession() throws {
        guard Self.authorizationAllowsCapture else {
            OSLogger.error("Camera video source could not be configured because camera access is denied.")
            throw VideoDeviceError.cameraAccessDenied
        }

        guard let device: AVCaptureDevice = makeCaptureDevice() else {
            OSLogger.error("Camera video source could not find a capture device.")
            throw VideoDeviceError.cameraUnavailable
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            OSLogger.error("Failed to create camera capture input: \(error)")
            throw error
        }

        captureSession.beginConfiguration()
        defer {
            captureSession.commitConfiguration()
        }

        captureSession.sessionPreset = makeSessionPreset(format: configuration.format)

        guard captureSession.canAddInput(input) else {
            OSLogger.error("Camera video source could not add the camera input.")
            throw VideoDeviceError.captureConfigurationFailed
        }

        captureSession.addInput(input)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)

        guard captureSession.canAddOutput(videoOutput) else {
            OSLogger.error("Camera video source could not add the video output.")
            throw VideoDeviceError.captureConfigurationFailed
        }

        captureSession.addOutput(videoOutput)
        try configureFrameRate(device: device)
    }

    private func makeCaptureDevice() -> AVCaptureDevice? {
        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: configuration.position.avCapturePosition
        )
        #else
        AVCaptureDevice.default(for: .video)
        #endif
    }

    private func makeSessionPreset(format: VideoFormat) -> AVCaptureSession.Preset {
        switch (format.width, format.height) {
        case (3840, 2160):
            return .hd4K3840x2160
        case (1920, 1080):
            return .hd1920x1080
        case (1280, 720):
            return .hd1280x720
        case (640, 480):
            return .vga640x480
        default:
            return .high
        }
    }

    private func configureFrameRate(device: AVCaptureDevice) throws {
        let duration: CMTime = CMTime(value: 1, timescale: CMTimeScale(configuration.format.framesPerSecond))

        do {
            try device.lockForConfiguration()
            defer {
                device.unlockForConfiguration()
            }
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
        } catch {
            OSLogger.error("Failed to configure camera frame rate: \(error)")
            throw error
        }
    }

    private func runOnSessionQueue(_ body: @escaping () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                do {
                    try body()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
