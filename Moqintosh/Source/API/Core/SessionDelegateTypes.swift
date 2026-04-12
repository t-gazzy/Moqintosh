//
//  SessionDelegateTypes.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/11.
//

/// Acceptance parameters for an inbound PUBLISH request.
public struct PublishAcceptance: Sendable {

    /// Whether the sender may forward the published content.
    public let forward: Bool
    /// The subscriber priority advertised in `PUBLISH_OK`.
    public let subscriberPriority: UInt8
    /// The group ordering advertised in `PUBLISH_OK`.
    public let groupOrder: GroupOrder
    /// The subscription filter advertised in `PUBLISH_OK`.
    public let filter: SubscriptionFilter
    /// The optional delivery timeout advertised in `PUBLISH_OK`.
    public let deliveryTimeout: UInt64?

    /// Creates an acceptance value for an inbound `PUBLISH`.
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

/// The decision returned for an inbound `PUBLISH_NAMESPACE`.
public enum PublishNamespaceDecision: Sendable {
    case accept
    case reject(PublishNamespaceRequestError)
}

/// The decision returned for an inbound `PUBLISH`.
public enum PublishDecision: Sendable {
    case accept(PublishAcceptance)
    case reject(PublishRequestError)
}

/// Acceptance parameters for an inbound SUBSCRIBE request.
public struct SubscribeAcceptance: Sendable {

    /// The published track bound to the accepted subscription.
    public let publishedTrack: PublishedTrack
    /// The expiry advertised in `SUBSCRIBE_OK`.
    public let expires: UInt64
    /// The optional delivery timeout advertised in `SUBSCRIBE_OK`.
    public let deliveryTimeout: UInt64?
    /// The optional cache duration advertised in `SUBSCRIBE_OK`.
    public let maxCacheDuration: UInt64?

    /// Creates an acceptance value for an inbound `SUBSCRIBE`.
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

/// The decision returned for an inbound `SUBSCRIBE_NAMESPACE`.
public enum SubscribeNamespaceDecision: Sendable {
    case accept
    case reject(SubscribeNamespaceRequestError)
}

/// The decision returned for an inbound `SUBSCRIBE`.
public enum SubscribeDecision: Sendable {
    case accept(SubscribeAcceptance)
    case reject(SubscribeRequestError)
}

/// The decision returned for an inbound `TRACK_STATUS`.
public enum TrackStatusDecision: Sendable {
    case accept(TrackStatus)
    case reject(TrackStatusRequestError)
}

/// The decision returned for an inbound `FETCH`.
public enum FetchDecision: Sendable {
    case accept(FetchResponse)
    case reject(FetchRequestError)
}

/// Error returned when rejecting an inbound PUBLISH_NAMESPACE request.
public struct PublishNamespaceRequestError: Error, Sendable {

    /// RFC-defined error code for `PUBLISH_NAMESPACE_ERROR`.
    public enum Code: UInt64, Sendable {
        case internalError = 0x0
        case unauthorized = 0x1
        case timeout = 0x2
        case notSupported = 0x3
        case uninterested = 0x4
        case malformedAuthToken = 0x10
        case expiredAuthToken = 0x12
    }

    /// The error code to encode in `PUBLISH_NAMESPACE_ERROR`.
    public let code: Code
    /// The reason phrase to encode in `PUBLISH_NAMESPACE_ERROR`.
    public let reason: String

    /// Creates a namespace rejection for an inbound `PUBLISH_NAMESPACE`.
    public init(code: Code, reason: String) {
        self.code = code
        self.reason = reason
    }
}

/// Error returned when rejecting an inbound PUBLISH request.
public struct PublishRequestError: Error, Sendable {

    /// RFC-defined error code for `PUBLISH_ERROR`.
    public enum Code: UInt64, Sendable {
        case internalError = 0x0
        case unauthorized = 0x1
        case timeout = 0x2
        case notSupported = 0x3
        case uninterested = 0x4
    }

    /// The error code to encode in `PUBLISH_ERROR`.
    public let code: Code
    /// The reason phrase to encode in `PUBLISH_ERROR`.
    public let reason: String

    /// Creates a rejection for an inbound `PUBLISH`.
    public init(code: Code, reason: String) {
        self.code = code
        self.reason = reason
    }
}

/// Error returned when rejecting an inbound SUBSCRIBE_NAMESPACE request.
public struct SubscribeNamespaceRequestError: Error, Sendable {

    /// RFC-defined error code for `SUBSCRIBE_NAMESPACE_ERROR`.
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

    /// The error code to encode in `SUBSCRIBE_NAMESPACE_ERROR`.
    public let code: Code
    /// The reason phrase to encode in `SUBSCRIBE_NAMESPACE_ERROR`.
    public let reason: String

    /// Creates a namespace rejection for an inbound `SUBSCRIBE_NAMESPACE`.
    public init(code: Code, reason: String) {
        self.code = code
        self.reason = reason
    }
}

/// Error returned when rejecting an inbound SUBSCRIBE request.
public struct SubscribeRequestError: Error, Sendable {

    /// RFC-defined error code for `SUBSCRIBE_ERROR`.
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

    /// The error code to encode in `SUBSCRIBE_ERROR`.
    public let code: Code
    /// The reason phrase to encode in `SUBSCRIBE_ERROR`.
    public let reason: String

    /// Creates a rejection for an inbound `SUBSCRIBE`.
    public init(code: Code, reason: String) {
        self.code = code
        self.reason = reason
    }
}

/// Error returned when rejecting an inbound TRACK_STATUS request.
public struct TrackStatusRequestError: Error, Sendable {

    /// RFC-defined error code for `TRACK_STATUS_ERROR`.
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

    /// The error code to encode in `TRACK_STATUS_ERROR`.
    public let code: Code
    /// The reason phrase to encode in `TRACK_STATUS_ERROR`.
    public let reason: String

    /// Creates a rejection for an inbound `TRACK_STATUS`.
    public init(code: Code, reason: String) {
        self.code = code
        self.reason = reason
    }
}

/// Error returned when rejecting an inbound FETCH request.
public struct FetchRequestError: Error, Sendable {

    /// RFC-defined error code for `FETCH_ERROR`.
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

    /// The error code to encode in `FETCH_ERROR`.
    public let code: Code
    /// The reason phrase to encode in `FETCH_ERROR`.
    public let reason: String

    /// Creates a rejection for an inbound `FETCH`.
    public init(code: Code, reason: String) {
        self.code = code
        self.reason = reason
    }
}
