//
//  TestSessionDelegate.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
@testable import Moqintosh

final class TestSessionDelegate: SessionDelegate {

    var publishNamespaceError: PublishNamespaceRequestError?
    var subscribeNamespaceError: SubscribeNamespaceRequestError?
    var publishError: PublishRequestError?
    var subscribeError: SubscribeRequestError?
    var fetchResponse: FetchResponse?
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
    private(set) var receivedFetchRequest: FetchRequest?
    private(set) var receivedFetchCancelRequestID: UInt64?
    private(set) var receivedPublishDone: PublishDone?
    private(set) var receivedPublishNamespaceDone: TrackNamespace?
    private(set) var receivedGoAwayURI: String?
    private(set) var receivedUnsubscribeNamespace: TrackNamespace?
    private(set) var receivedPublishNamespaceCancel: PublishNamespaceCancel?

    init() {
        self.publishNamespaceError = nil
        self.subscribeNamespaceError = nil
        self.publishError = nil
        self.subscribeError = nil
        self.fetchResponse = nil
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
        self.receivedFetchRequest = nil
        self.receivedFetchCancelRequestID = nil
        self.receivedPublishDone = nil
        self.receivedPublishNamespaceDone = nil
        self.receivedGoAwayURI = nil
        self.receivedUnsubscribeNamespace = nil
        self.receivedPublishNamespaceCancel = nil
    }

    func session(
        _ session: Session,
        didReceiveSubscribeNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) -> SubscribeNamespaceDecision {
        receivedSubscribeNamespace = prefix
        receivedSubscribeNamespaceAuthorizationToken = authorizationToken
        if let subscribeNamespaceError: SubscribeNamespaceRequestError = subscribeNamespaceError {
            return .reject(subscribeNamespaceError)
        }
        return .accept
    }

    func session(_ session: Session, didReceiveSubscribe publishedTrack: PublishedTrack) -> SubscribeDecision {
        receivedSubscribeTrack = publishedTrack
        if let subscribeError: SubscribeRequestError = subscribeError {
            return .reject(subscribeError)
        }
        return .accept(SubscribeAcceptance(publishedTrack: publishedTrack))
    }

    func session(
        _ session: Session,
        didReceivePublishNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) -> PublishNamespaceDecision {
        receivedPublishNamespace = prefix
        receivedPublishNamespaceAuthorizationToken = authorizationToken
        if let publishNamespaceError: PublishNamespaceRequestError = publishNamespaceError {
            return .reject(publishNamespaceError)
        }
        return .accept
    }

    func session(_ session: Session, didReceivePublish resource: TrackResource) -> PublishDecision {
        receivedPublishResource = resource
        if let publishError: PublishRequestError = publishError {
            return .reject(publishError)
        }
        return .accept(PublishAcceptance())
    }

    func session(_ session: Session, didReceiveSubscribeUpdate update: SubscribeUpdate) {
        receivedSubscribeUpdate = update
    }

    func session(_ session: Session, didReceiveUnsubscribe requestID: UInt64) {
        receivedUnsubscribeRequestID = requestID
    }

    func session(_ session: Session, didReceiveTrackStatus request: TrackStatusRequest) -> TrackStatusDecision {
        receivedTrackStatusRequest = request
        if let trackStatusResult {
            return .accept(trackStatusResult)
        }
        return .reject(TrackStatusRequestError(code: .trackDoesNotExist, reason: "Track does not exist"))
    }

    func session(_ session: Session, didReceiveFetch request: FetchRequest) -> FetchDecision {
        receivedFetchRequest = request
        if let fetchResponse {
            return .accept(fetchResponse)
        }
        return .reject(FetchRequestError(code: .trackDoesNotExist, reason: "Track does not exist"))
    }

    func session(_ session: Session, didReceiveFetchCancel requestID: UInt64) {
        receivedFetchCancelRequestID = requestID
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
