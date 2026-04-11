//
//  TestSessionDelegate.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
@testable import Moqintosh

final class TestSessionDelegate: SessionDelegate {

    var publishNamespaceResult: Bool
    var subscribeNamespaceResult: Bool
    var publishResult: Bool
    var subscribeResult: Bool
    var trackStatusResult: TrackStatus?
    private(set) var receivedPublishNamespace: TrackNamespace?
    private(set) var receivedPublishNamespaceAuthorizationToken: AuthorizationToken?
    private(set) var receivedSubscribeNamespace: TrackNamespace?
    private(set) var receivedSubscribeNamespaceAuthorizationToken: AuthorizationToken?
    private(set) var receivedPublishResource: TrackResource?
    private(set) var receivedSubscribeTrack: PublishedTrack?
    private(set) var receivedSubscribeUpdate: SubscribeUpdate?
    private(set) var receivedUnsubscribeRequestID: UInt64?
    private(set) var receivedTrackStatusRequest: TrackStatusRequest?
    private(set) var receivedPublishDone: PublishDone?
    private(set) var receivedPublishNamespaceDone: TrackNamespace?
    private(set) var receivedGoAwayURI: String?
    private(set) var receivedUnsubscribeNamespace: TrackNamespace?
    private(set) var receivedPublishNamespaceCancel: PublishNamespaceCancel?

    init() {
        self.publishNamespaceResult = false
        self.subscribeNamespaceResult = false
        self.publishResult = false
        self.subscribeResult = false
        self.trackStatusResult = nil
        self.receivedPublishNamespace = nil
        self.receivedPublishNamespaceAuthorizationToken = nil
        self.receivedSubscribeNamespace = nil
        self.receivedSubscribeNamespaceAuthorizationToken = nil
        self.receivedPublishResource = nil
        self.receivedSubscribeTrack = nil
        self.receivedSubscribeUpdate = nil
        self.receivedUnsubscribeRequestID = nil
        self.receivedTrackStatusRequest = nil
        self.receivedPublishDone = nil
        self.receivedPublishNamespaceDone = nil
        self.receivedGoAwayURI = nil
        self.receivedUnsubscribeNamespace = nil
        self.receivedPublishNamespaceCancel = nil
    }

    func session(
        _ session: Session,
        shouldAcceptSubscribeNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) -> Bool {
        receivedSubscribeNamespace = prefix
        receivedSubscribeNamespaceAuthorizationToken = authorizationToken
        return subscribeNamespaceResult
    }

    func session(_ session: Session, didReceiveSubscribe publishedTrack: PublishedTrack) -> Bool {
        receivedSubscribeTrack = publishedTrack
        return subscribeResult
    }

    func session(
        _ session: Session,
        shouldAcceptPublishNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) -> Bool {
        receivedPublishNamespace = prefix
        receivedPublishNamespaceAuthorizationToken = authorizationToken
        return publishNamespaceResult
    }

    func session(_ session: Session, didReceivePublish resource: TrackResource) -> Bool {
        receivedPublishResource = resource
        return publishResult
    }

    func session(_ session: Session, didReceiveSubscribeUpdate update: SubscribeUpdate) {
        receivedSubscribeUpdate = update
    }

    func session(_ session: Session, didReceiveUnsubscribe requestID: UInt64) {
        receivedUnsubscribeRequestID = requestID
    }

    func session(_ session: Session, didReceiveTrackStatus request: TrackStatusRequest) throws -> TrackStatus {
        receivedTrackStatusRequest = request
        if let trackStatusResult {
            return trackStatusResult
        }
        throw TrackStatusRequestError.rejected(code: 0x0, reason: "Rejected")
    }

    func session(_ session: Session, didReceivePublishDone publishDone: PublishDone) {
        receivedPublishDone = publishDone
    }

    func session(_ session: Session, didReceivePublishNamespaceDone trackNamespace: TrackNamespace) {
        receivedPublishNamespaceDone = trackNamespace
    }

    func session(_ session: Session, didReceiveGoAway newSessionURI: String?) {
        receivedGoAwayURI = newSessionURI
    }

    func session(_ session: Session, didReceiveUnsubscribeNamespace namespacePrefix: TrackNamespace) {
        receivedUnsubscribeNamespace = namespacePrefix
    }

    func session(_ session: Session, didReceivePublishNamespaceCancel cancellation: PublishNamespaceCancel) {
        receivedPublishNamespaceCancel = cancellation
    }
}
