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
    private(set) var receivedPublishNamespace: TrackNamespace?
    private(set) var receivedPublishNamespaceAuthorizationToken: AuthorizationToken?
    private(set) var receivedSubscribeNamespace: TrackNamespace?
    private(set) var receivedSubscribeNamespaceAuthorizationToken: AuthorizationToken?
    private(set) var receivedPublishResource: TrackResource?
    private(set) var receivedSubscribeTrack: PublishedTrack?

    init() {
        self.publishNamespaceResult = false
        self.subscribeNamespaceResult = false
        self.publishResult = false
        self.subscribeResult = false
        self.receivedPublishNamespace = nil
        self.receivedPublishNamespaceAuthorizationToken = nil
        self.receivedSubscribeNamespace = nil
        self.receivedSubscribeNamespaceAuthorizationToken = nil
        self.receivedPublishResource = nil
        self.receivedSubscribeTrack = nil
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
}
