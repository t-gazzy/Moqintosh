//
//  SessionDelegate.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

/// Receives inbound control messages forwarded by a ``Session``.
///
/// Implement this protocol to react to messages sent by the remote peer.
/// All methods have a default no-op implementation so you only override what you need.
public protocol SessionDelegate: AnyObject {

    // MARK: - Publisher-facing events (sent by the remote Subscriber)

    /// The remote subscriber requested a namespace subscription (Section 9.28).
    func session(
        _ session: Session,
        didReceiveSubscribeNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) -> SubscribeNamespaceDecision

    /// The remote subscriber requested a new subscription (Section 9.7).
    func session(_ session: Session, didReceiveSubscribe publishedTrack: PublishedTrack) -> SubscribeDecision

    /// The remote subscriber updated an existing subscription (Section 9.10).
    func session(_ session: Session, didReceiveSubscribeUpdate update: SubscribeUpdate)

    /// The remote subscriber cancelled a subscription (Section 9.11).
    func session(_ session: Session, didReceiveUnsubscribe requestID: UInt64)

    /// The remote subscriber requested a fetch (Section 9.16).
    func session(_ session: Session, didReceiveFetch request: FetchRequest) -> FetchDecision

    /// The remote subscriber cancelled a fetch (Section 9.19).
    func session(_ session: Session, didReceiveFetchCancel requestID: UInt64)

    /// The remote subscriber requested track status (Section 9.20).
    func session(_ session: Session, didReceiveTrackStatus request: TrackStatusRequest) -> TrackStatusDecision

    // MARK: - Subscriber-facing events (sent by the remote Publisher)

    /// The remote publisher announced a namespace (Section 9.23).
    func session(
        _ session: Session,
        didReceivePublishNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) -> PublishNamespaceDecision

    /// The remote publisher initiated a publish for a track (Section 9.13).
    func session(_ session: Session, didReceivePublish resource: TrackResource) -> PublishDecision

    /// The remote publisher signalled end of publish (Section 9.12).
    func session(_ session: Session, didReceivePublishDone publishDone: PublishDone)

    /// The remote publisher ended a namespace (Section 9.26).
    func session(_ session: Session, didReceivePublishNamespaceDone trackNamespace: TrackNamespace)

    /// The remote peer sent GOAWAY (Section 9.4).
    func session(_ session: Session, didReceiveGoAway newSessionURI: String?)

    /// The remote subscriber cancelled namespace interest (Section 9.31).
    func session(_ session: Session, didReceiveUnsubscribeNamespace namespacePrefix: TrackNamespace)

    /// The remote subscriber cancelled a published namespace (Section 9.27).
    func session(_ session: Session, didReceivePublishNamespaceCancel cancellation: PublishNamespaceCancel)
}

// MARK: - Default implementations

public extension SessionDelegate {
    func session(
        _ session: Session,
        didReceiveSubscribeNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) -> SubscribeNamespaceDecision {
        .reject(
            SubscribeNamespaceRequestError(
                code: .namespacePrefixUnknown,
                reason: "Namespace prefix unknown"
            )
        )
    }

    func session(_ session: Session, didReceiveSubscribe publishedTrack: PublishedTrack) -> SubscribeDecision {
        .reject(
            SubscribeRequestError(
                code: .trackDoesNotExist,
                reason: "Track does not exist"
            )
        )
    }
    func session(_ session: Session, didReceiveSubscribeUpdate update: SubscribeUpdate) {}
    func session(_ session: Session, didReceiveUnsubscribe requestID: UInt64) {}
    func session(_ session: Session, didReceiveFetch request: FetchRequest) -> FetchDecision {
        .reject(FetchRequestError(code: .trackDoesNotExist, reason: "Track does not exist"))
    }
    func session(_ session: Session, didReceiveFetchCancel requestID: UInt64) {}
    func session(_ session: Session, didReceiveTrackStatus request: TrackStatusRequest) -> TrackStatusDecision {
        .reject(TrackStatusRequestError(code: .trackDoesNotExist, reason: "Track does not exist"))
    }

    func session(
        _ session: Session,
        didReceivePublishNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) -> PublishNamespaceDecision {
        .reject(
            PublishNamespaceRequestError(
                code: .uninterested,
                reason: "Uninterested"
            )
        )
    }

    func session(_ session: Session, didReceivePublish resource: TrackResource) -> PublishDecision {
        .reject(PublishRequestError(code: .uninterested, reason: "Uninterested"))
    }
    func session(_ session: Session, didReceivePublishDone publishDone: PublishDone) {}
    func session(_ session: Session, didReceivePublishNamespaceDone trackNamespace: TrackNamespace) {}
    func session(_ session: Session, didReceiveGoAway newSessionURI: String?) {}
    func session(_ session: Session, didReceiveUnsubscribeNamespace namespacePrefix: TrackNamespace) {}
    func session(_ session: Session, didReceivePublishNamespaceCancel cancellation: PublishNamespaceCancel) {}
}
