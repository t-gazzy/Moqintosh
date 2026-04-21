//
//  VideoEncodedPacket.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import CoreMedia
import Foundation

public struct VideoEncodedPacket: Sendable {
    public let payload: Data
    public let presentationTime: CMTime
    public let duration: CMTime
    public let sourceFormat: VideoFormat
    public let isKeyFrame: Bool
    public let parameterSets: H264ParameterSets?

    public init(
        payload: Data,
        presentationTime: CMTime,
        duration: CMTime,
        sourceFormat: VideoFormat,
        isKeyFrame: Bool,
        parameterSets: H264ParameterSets?
    ) {
        self.payload = payload
        self.presentationTime = presentationTime
        self.duration = duration
        self.sourceFormat = sourceFormat
        self.isKeyFrame = isKeyFrame
        self.parameterSets = parameterSets
    }
}
