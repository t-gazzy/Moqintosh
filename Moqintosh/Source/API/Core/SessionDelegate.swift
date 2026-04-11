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
        shouldAcceptSubscribeNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) -> Bool

    /// The remote subscriber requested a namespace subscription (Section 9.28).
    func session(
        _ session: Session,
        didReceiveSubscribeNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    )

    /// The remote subscriber requested a new subscription (Section 9.7).
    func session(_ session: Session, didReceiveSubscribe publishedTrack: PublishedTrack) -> Bool

    /// The remote subscriber updated an existing subscription (Section 9.10).
    func session(_ session: Session, didReceiveSubscribeUpdate update: SubscribeUpdate)

    /// The remote subscriber cancelled a subscription (Section 9.11).
    func session(_ session: Session, didReceiveUnsubscribe requestID: UInt64)

    /// The remote subscriber requested a fetch (Section 9.16).
    func session(_ session: Session, didReceiveFetch message: String)

    /// The remote subscriber cancelled a fetch (Section 9.19).
    func session(_ session: Session, didReceiveFetchCancel message: String)

    /// The remote subscriber requested track status (Section 9.20).
    func session(_ session: Session, didReceiveTrackStatus request: TrackStatusRequest) throws -> TrackStatus

    // MARK: - Subscriber-facing events (sent by the remote Publisher)

    /// The remote publisher announced a namespace (Section 9.23).
    func session(
        _ session: Session,
        shouldAcceptPublishNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) -> Bool

    /// The remote publisher announced a namespace (Section 9.23).
    func session(
        _ session: Session,
        didReceivePublishNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    )

    /// The remote publisher initiated a publish for a track (Section 9.13).
    func session(_ session: Session, didReceivePublish resource: TrackResource) -> Bool

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
        shouldAcceptSubscribeNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) -> Bool {
        false
    }

    func session(
        _ session: Session,
        didReceiveSubscribeNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) {}

    func session(_ session: Session, didReceiveSubscribe publishedTrack: PublishedTrack) -> Bool {
        false
    }
    func session(_ session: Session, didReceiveSubscribeUpdate update: SubscribeUpdate) {}
    func session(_ session: Session, didReceiveUnsubscribe requestID: UInt64) {}
    func session(_ session: Session, didReceiveFetch message: String) {}
    func session(_ session: Session, didReceiveFetchCancel message: String) {}
    func session(_ session: Session, didReceiveTrackStatus request: TrackStatusRequest) throws -> TrackStatus {
        throw TrackStatusRequestError.rejected(code: 0x0, reason: "Rejected")
    }
    func session(
        _ session: Session,
        shouldAcceptPublishNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) -> Bool {
        false
    }

    func session(
        _ session: Session,
        didReceivePublishNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) {}

    func session(_ session: Session, didReceivePublish resource: TrackResource) -> Bool {
        false
    }
    func session(_ session: Session, didReceivePublishDone publishDone: PublishDone) {}
    func session(_ session: Session, didReceivePublishNamespaceDone trackNamespace: TrackNamespace) {}
    func session(_ session: Session, didReceiveGoAway newSessionURI: String?) {}
    func session(_ session: Session, didReceiveUnsubscribeNamespace namespacePrefix: TrackNamespace) {}
    func session(_ session: Session, didReceivePublishNamespaceCancel cancellation: PublishNamespaceCancel) {}
}
