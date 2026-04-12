//
//  FetchResponse.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

public struct FetchResponse {

    public let groupOrder: GroupOrder
    public let endOfTrack: Bool
    public let endLocation: Location
    public let maxCacheDuration: UInt64?

    public init(
        groupOrder: GroupOrder,
        endOfTrack: Bool,
        endLocation: Location,
        maxCacheDuration: UInt64?
    ) {
        self.groupOrder = groupOrder
        self.endOfTrack = endOfTrack
        self.endLocation = endLocation
        self.maxCacheDuration = maxCacheDuration
    }
}
