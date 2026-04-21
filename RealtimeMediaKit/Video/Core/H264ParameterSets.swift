//
//  H264ParameterSets.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/21.
//

import Foundation

public struct H264ParameterSets: Sendable, Equatable {
    public let sequenceParameterSet: Data
    public let pictureParameterSet: Data

    public init(sequenceParameterSet: Data, pictureParameterSet: Data) {
        self.sequenceParameterSet = sequenceParameterSet
        self.pictureParameterSet = pictureParameterSet
    }
}
