//
//  SessionDelegateTypes.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/11.
//

/// Acceptance parameters for an inbound PUBLISH request.
public struct PublishAcceptance: Sendable {

    public let forward: Bool
    public let subscriberPriority: UInt8
    public let groupOrder: GroupOrder
    public let filter: SubscriptionFilter
    public let deliveryTimeout: UInt64?

    public init(
        forward: Bool = true,
        subscriberPriority: UInt8 = 128,
        groupOrder: GroupOrder = .ascending,
        filter: SubscriptionFilter = .largestObject,
        deliveryTimeout: UInt64? = nil
    ) {
        self.forward = forward
        self.subscriberPriority = subscriberPriority
        self.groupOrder = groupOrder
        self.filter = filter
        self.deliveryTimeout = deliveryTimeout
    }
}

public enum PublishNamespaceDecision: Sendable {
    case accept
    case reject(PublishNamespaceRequestError)
}

public enum PublishDecision: Sendable {
    case accept(PublishAcceptance)
    case reject(PublishRequestError)
}

/// Acceptance parameters for an inbound SUBSCRIBE request.
public struct SubscribeAcceptance: Sendable {

    public let publishedTrack: PublishedTrack
    public let expires: UInt64
    public let deliveryTimeout: UInt64?
    public let maxCacheDuration: UInt64?

    public init(
        publishedTrack: PublishedTrack,
        expires: UInt64 = 0,
        deliveryTimeout: UInt64? = nil,
        maxCacheDuration: UInt64? = nil
    ) {
        self.publishedTrack = publishedTrack
        self.expires = expires
        self.deliveryTimeout = deliveryTimeout
        self.maxCacheDuration = maxCacheDuration
    }
}

public enum SubscribeNamespaceDecision: Sendable {
    case accept
    case reject(SubscribeNamespaceRequestError)
}

public enum SubscribeDecision: Sendable {
    case accept(SubscribeAcceptance)
    case reject(SubscribeRequestError)
}

public enum TrackStatusDecision: Sendable {
    case accept(TrackStatus)
    case reject(TrackStatusRequestError)
}

public enum FetchDecision: Sendable {
    case accept(FetchResponse)
    case reject(FetchRequestError)
}

/// Error returned when rejecting an inbound PUBLISH_NAMESPACE request.
public struct PublishNamespaceRequestError: Error, Sendable {

    public enum Code: UInt64, Sendable {
        case internalError = 0x0
        case unauthorized = 0x1
        case timeout = 0x2
        case notSupported = 0x3
        case uninterested = 0x4
        case malformedAuthToken = 0x10
        case expiredAuthToken = 0x12
    }

    public let code: Code
    public let reason: String

    public init(code: Code, reason: String) {
        self.code = code
        self.reason = reason
    }
}

/// Error returned when rejecting an inbound PUBLISH request.
public struct PublishRequestError: Error, Sendable {

    public enum Code: UInt64, Sendable {
        case internalError = 0x0
        case unauthorized = 0x1
        case timeout = 0x2
        case notSupported = 0x3
        case uninterested = 0x4
    }

    public let code: Code
    public let reason: String

    public init(code: Code, reason: String) {
        self.code = code
        self.reason = reason
    }
}

/// Error returned when rejecting an inbound SUBSCRIBE_NAMESPACE request.
public struct SubscribeNamespaceRequestError: Error, Sendable {

    public enum Code: UInt64, Sendable {
        case internalError = 0x0
        case unauthorized = 0x1
        case timeout = 0x2
        case notSupported = 0x3
        case namespacePrefixUnknown = 0x4
        case namespacePrefixOverlap = 0x5
        case malformedAuthToken = 0x10
        case expiredAuthToken = 0x12
    }

    public let code: Code
    public let reason: String

    public init(code: Code, reason: String) {
        self.code = code
        self.reason = reason
    }
}

/// Error returned when rejecting an inbound SUBSCRIBE request.
public struct SubscribeRequestError: Error, Sendable {

    public enum Code: UInt64, Sendable {
        case internalError = 0x0
        case unauthorized = 0x1
        case timeout = 0x2
        case notSupported = 0x3
        case trackDoesNotExist = 0x4
        case invalidRange = 0x5
        case malformedAuthToken = 0x10
        case expiredAuthToken = 0x12
    }

    public let code: Code
    public let reason: String

    public init(code: Code, reason: String) {
        self.code = code
        self.reason = reason
    }
}

/// Error returned when rejecting an inbound TRACK_STATUS request.
public struct TrackStatusRequestError: Error, Sendable {

    public enum Code: UInt64, Sendable {
        case internalError = 0x0
        case unauthorized = 0x1
        case timeout = 0x2
        case notSupported = 0x3
        case trackDoesNotExist = 0x4
        case invalidRange = 0x5
        case malformedAuthToken = 0x10
        case expiredAuthToken = 0x12
    }

    public let code: Code
    public let reason: String

    public init(code: Code, reason: String) {
        self.code = code
        self.reason = reason
    }
}

/// Error returned when rejecting an inbound FETCH request.
public struct FetchRequestError: Error, Sendable {

    public enum Code: UInt64, Sendable {
        case internalError = 0x0
        case unauthorized = 0x1
        case timeout = 0x2
        case notSupported = 0x3
        case trackDoesNotExist = 0x4
        case invalidRange = 0x5
        case noObjects = 0x6
        case invalidJoiningRequestID = 0x7
        case unknownStatusInRange = 0x8
        case malformedTrack = 0x9
        case malformedAuthToken = 0x10
        case expiredAuthToken = 0x12
    }

    public let code: Code
    public let reason: String

    public init(code: Code, reason: String) {
        self.code = code
        self.reason = reason
    }
}
