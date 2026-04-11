//
//  TrackStatus.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

public struct TrackStatus {

    public let expires: UInt64
    public let groupOrder: GroupOrder
    public let contentExist: ContentExist
    public let deliveryTimeout: UInt64?
    public let maxCacheDuration: UInt64?

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
