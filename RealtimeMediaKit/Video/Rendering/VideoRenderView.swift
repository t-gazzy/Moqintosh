//
//  VideoRenderView.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

#if canImport(UIKit)
import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import UIKit

@MainActor
public final class VideoRenderView: UIView {
    public override class var layerClass: AnyClass {
        AVSampleBufferDisplayLayer.self
    }

    public var videoGravity: AVLayerVideoGravity {
        get {
            displayLayer.videoGravity
        }
        set {
            displayLayer.videoGravity = newValue
        }
    }

    private var displayLayer: AVSampleBufferDisplayLayer {
        guard let layer: AVSampleBufferDisplayLayer = layer as? AVSampleBufferDisplayLayer else {
            preconditionFailure("VideoRenderView must be backed by AVSampleBufferDisplayLayer.")
        }

        return layer
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configureDisplayLayer()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureDisplayLayer()
    }

    public func enqueue(_ frame: VideoFrame) throws {
        let sampleBuffer: CMSampleBuffer = try Self.makeSampleBuffer(frame: frame)
        displayLayer.sampleBufferRenderer.enqueue(sampleBuffer)
    }

    public func flush() {
        displayLayer.sampleBufferRenderer.flush()
    }

    public func flushAndRemoveImage() {
        displayLayer.sampleBufferRenderer.flush(removingDisplayedImage: true)
    }
}

extension VideoRenderView {
    private func configureDisplayLayer() {
        displayLayer.videoGravity = .resizeAspect
    }

    private static func makeSampleBuffer(frame: VideoFrame) throws -> CMSampleBuffer {
        var formatDescription: CMVideoFormatDescription?
        let formatStatus: OSStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: frame.pixelBuffer,
            formatDescriptionOut: &formatDescription
        )

        guard formatStatus == noErr, let formatDescription else {
            OSLogger.error("Failed to create video render format description. status=\(formatStatus)")
            throw VideoDeviceError.videoDecodingFailed(status: formatStatus)
        }

        var timing: CMSampleTimingInfo = CMSampleTimingInfo(
            duration: frame.duration,
            presentationTimeStamp: frame.presentationTime,
            decodeTimeStamp: CMTime.invalid
        )
        var sampleBuffer: CMSampleBuffer?
        let sampleStatus: OSStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: frame.pixelBuffer,
            formatDescription: formatDescription,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )

        guard sampleStatus == noErr, let sampleBuffer else {
            OSLogger.error("Failed to create video render sample buffer. status=\(sampleStatus)")
            throw VideoDeviceError.videoDecodingFailed(status: sampleStatus)
        }

        return sampleBuffer
    }
}
#endif
