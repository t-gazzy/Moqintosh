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

    /// The remote subscriber requested a new subscription (Section 9.7).
    func session(_ session: Session, didReceiveSubscribe message: String)

    /// The remote subscriber updated an existing subscription (Section 9.10).
    func session(_ session: Session, didReceiveSubscribeUpdate message: String)

    /// The remote subscriber cancelled a subscription (Section 9.11).
    func session(_ session: Session, didReceiveUnsubscribe message: String)

    /// The remote subscriber requested a fetch (Section 9.16).
    func session(_ session: Session, didReceiveFetch message: String)

    /// The remote subscriber cancelled a fetch (Section 9.19).
    func session(_ session: Session, didReceiveFetchCancel message: String)

    /// The remote subscriber requested track status (Section 9.20).
    func session(_ session: Session, didReceiveTrackStatus message: String)

    // MARK: - Subscriber-facing events (sent by the remote Publisher)

    /// The remote publisher announced a namespace (Section 9.23).
    func session(
        _ session: Session,
        shouldAcceptPublishNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) -> Bool

    /// The remote publisher initiated a publish for a track (Section 9.13).
    func session(_ session: Session, didReceivePublish message: String)

    /// The remote publisher signalled end of publish (Section 9.12).
    func session(_ session: Session, didReceivePublishDone message: String)

    /// The remote publisher ended a namespace (Section 9.26).
    func session(_ session: Session, didReceivePublishNamespaceDone message: String)
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

    func session(_ session: Session, didReceiveSubscribe message: String) {}
    func session(_ session: Session, didReceiveSubscribeUpdate message: String) {}
    func session(_ session: Session, didReceiveUnsubscribe message: String) {}
    func session(_ session: Session, didReceiveFetch message: String) {}
    func session(_ session: Session, didReceiveFetchCancel message: String) {}
    func session(_ session: Session, didReceiveTrackStatus message: String) {}
    func session(
        _ session: Session,
        shouldAcceptPublishNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) -> Bool {
        false
    }

    func session(_ session: Session, didReceivePublish message: String) {}
    func session(_ session: Session, didReceivePublishDone message: String) {}
    func session(_ session: Session, didReceivePublishNamespaceDone message: String) {}
}
