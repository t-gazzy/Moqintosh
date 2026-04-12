//
//  FetchRequest.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

/// Represents an inbound `FETCH` request.
public enum FetchRequest {
    case standalone(
        requestID: UInt64,
        resource: TrackResource,
        subscriberPriority: UInt8,
        groupOrder: GroupOrder,
        start: Location,
        end: Location
    )
    case joiningRelative(
        requestID: UInt64,
        joiningRequestID: UInt64,
        resource: TrackResource,
        subscriberPriority: UInt8,
        groupOrder: GroupOrder,
        startGroupOffset: UInt64
    )
    case joiningAbsolute(
        requestID: UInt64,
        joiningRequestID: UInt64,
        resource: TrackResource,
        subscriberPriority: UInt8,
        groupOrder: GroupOrder,
        startGroup: UInt64
    )

    /// The request identifier associated with the fetch request.
    public var requestID: UInt64 {
        switch self {
        case .standalone(let requestID, _, _, _, _, _):
            return requestID
        case .joiningRelative(let requestID, _, _, _, _, _):
            return requestID
        case .joiningAbsolute(let requestID, _, _, _, _, _):
            return requestID
        }
    }
}
