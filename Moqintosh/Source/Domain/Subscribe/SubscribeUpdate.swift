//
//  SubscribeUpdate.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

public struct SubscribeUpdate {

    public let requestID: UInt64
    public let start: Location
    public let endGroup: UInt64
    public let subscriberPriority: UInt8
    public let forward: Bool
    public let authorizationToken: AuthorizationToken?

    public init(
        requestID: UInt64,
        start: Location,
        endGroup: UInt64,
        subscriberPriority: UInt8,
        forward: Bool,
        authorizationToken: AuthorizationToken?
    ) {
        self.requestID = requestID
        self.start = start
        self.endGroup = endGroup
        self.subscriberPriority = subscriberPriority
        self.forward = forward
        self.authorizationToken = authorizationToken
    }
}
