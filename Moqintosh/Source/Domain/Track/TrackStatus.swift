//
//  TrackStatus.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

/// Acceptance parameters returned for an inbound `TRACK_STATUS`.
public struct TrackStatus: Sendable {

    /// The expiry advertised in `TRACK_STATUS_OK`.
    public let expires: UInt64
    /// The group ordering advertised in `TRACK_STATUS_OK`.
    public let groupOrder: GroupOrder
    /// The content existence advertised in `TRACK_STATUS_OK`.
    public let contentExist: ContentExist
    /// The optional delivery timeout advertised in `TRACK_STATUS_OK`.
    public let deliveryTimeout: UInt64?
    /// The optional cache duration advertised in `TRACK_STATUS_OK`.
    public let maxCacheDuration: UInt64?

    /// Creates a track status value.
    public init(
        expires: UInt64,
        groupOrder: GroupOrder,
        contentExist: ContentExist,
        deliveryTimeout: UInt64?,
        maxCacheDuration: UInt64?
    ) {
        self.expires = expires
        self.groupOrder = groupOrder
        self.contentExist = contentExist
        self.deliveryTimeout = deliveryTimeout
        self.maxCacheDuration = maxCacheDuration
    }
}
