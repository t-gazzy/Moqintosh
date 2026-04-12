//
//  SubscribeUpdate.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

/// Represents a `SUBSCRIBE_UPDATE` received from the peer.
public struct SubscribeUpdate {

    /// The request identifier of the subscription being updated.
    public let requestID: UInt64
    /// The new starting location.
    public let start: Location
    /// The final group included in the update.
    public let endGroup: UInt64
    /// The requested subscriber priority.
    public let subscriberPriority: UInt8
    /// Whether forwarding is requested.
    public let forward: Bool
    /// The optional authorization token supplied with the update.
    public let authorizationToken: AuthorizationToken?

    /// Creates a subscribe-update value.
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
