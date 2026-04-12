//
//  FetchResponse.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

/// Acceptance parameters returned for an inbound `FETCH`.
public struct FetchResponse: Sendable {

    /// The group ordering advertised in `FETCH_OK`.
    public let groupOrder: GroupOrder
    /// Whether the fetch response reaches the end of the track.
    public let endOfTrack: Bool
    /// The ending location advertised in `FETCH_OK`.
    public let endLocation: Location
    /// The optional cache duration advertised in `FETCH_OK`.
    public let maxCacheDuration: UInt64?

    /// Creates a fetch response.
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
