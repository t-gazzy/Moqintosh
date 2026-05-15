//
//  TestSessionDelegate.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Synchronization
@testable import Moqintosh

final class TestSessionDelegate: SessionDelegate {

    private struct State {

        var publishNamespaceError: PublishNamespaceRequestError?
        var subscribeNamespaceError: SubscribeNamespaceRequestError?
        var publishError: PublishRequestError?
        var subscribeError: SubscribeRequestError?
        var fetchResponse: FetchResponse?
        var trackStatusResult: TrackStatus?
        var receivedPublishNamespace: TrackNamespace?
        var receivedPublishNamespaceAuthorizationToken: AuthorizationToken?
        var receivedSubscribeNamespace: TrackNamespace?
        var receivedSubscribeNamespaceAuthorizationToken: AuthorizationToken?
        var receivedPublishResource: TrackResource?
        var receivedSubscribeTrack: PublishedTrack?
        var receivedSubscribeUpdate: SubscribeUpdate?
        var receivedUnsubscribeRequestID: UInt64?
        var receivedTrackStatusRequest: TrackStatusRequest?
        var receivedFetchRequest: FetchRequest?
        var receivedFetchCancelRequestID: UInt64?
        var receivedPublishDone: PublishDone?
        var receivedPublishNamespaceDone: TrackNamespace?
        var receivedGoAwayURI: String?
        var receivedUnsubscribeNamespace: TrackNamespace?
        var receivedPublishNamespaceCancel: PublishNamespaceCancel?

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
    }

    private let state: Mutex<State>

    var publishNamespaceError: PublishNamespaceRequestError? {
        get { state.withLock { state in state.publishNamespaceError } }
        set { state.withLock { state in state.publishNamespaceError = newValue } }
    }

    var subscribeNamespaceError: SubscribeNamespaceRequestError? {
        get { state.withLock { state in state.subscribeNamespaceError } }
        set { state.withLock { state in state.subscribeNamespaceError = newValue } }
    }

    var publishError: PublishRequestError? {
        get { state.withLock { state in state.publishError } }
        set { state.withLock { state in state.publishError = newValue } }
    }

    var subscribeError: SubscribeRequestError? {
        get { state.withLock { state in state.subscribeError } }
        set { state.withLock { state in state.subscribeError = newValue } }
    }

    var fetchResponse: FetchResponse? {
        get { state.withLock { state in state.fetchResponse } }
        set { state.withLock { state in state.fetchResponse = newValue } }
    }

    var trackStatusResult: TrackStatus? {
        get { state.withLock { state in state.trackStatusResult } }
        set { state.withLock { state in state.trackStatusResult = newValue } }
    }

    private(set) var receivedPublishNamespace: TrackNamespace? {
        get { state.withLock { state in state.receivedPublishNamespace } }
        set { state.withLock { state in state.receivedPublishNamespace = newValue } }
    }

    private(set) var receivedPublishNamespaceAuthorizationToken: AuthorizationToken? {
        get { state.withLock { state in state.receivedPublishNamespaceAuthorizationToken } }
        set { state.withLock { state in state.receivedPublishNamespaceAuthorizationToken = newValue } }
    }

    private(set) var receivedSubscribeNamespace: TrackNamespace? {
        get { state.withLock { state in state.receivedSubscribeNamespace } }
        set { state.withLock { state in state.receivedSubscribeNamespace = newValue } }
    }

    private(set) var receivedSubscribeNamespaceAuthorizationToken: AuthorizationToken? {
        get { state.withLock { state in state.receivedSubscribeNamespaceAuthorizationToken } }
        set { state.withLock { state in state.receivedSubscribeNamespaceAuthorizationToken = newValue } }
    }

    private(set) var receivedPublishResource: TrackResource? {
        get { state.withLock { state in state.receivedPublishResource } }
        set { state.withLock { state in state.receivedPublishResource = newValue } }
    }

    private(set) var receivedSubscribeTrack: PublishedTrack? {
        get { state.withLock { state in state.receivedSubscribeTrack } }
        set { state.withLock { state in state.receivedSubscribeTrack = newValue } }
    }

    private(set) var receivedSubscribeUpdate: SubscribeUpdate? {
        get { state.withLock { state in state.receivedSubscribeUpdate } }
        set { state.withLock { state in state.receivedSubscribeUpdate = newValue } }
    }

    private(set) var receivedUnsubscribeRequestID: UInt64? {
        get { state.withLock { state in state.receivedUnsubscribeRequestID } }
        set { state.withLock { state in state.receivedUnsubscribeRequestID = newValue } }
    }

    private(set) var receivedTrackStatusRequest: TrackStatusRequest? {
        get { state.withLock { state in state.receivedTrackStatusRequest } }
        set { state.withLock { state in state.receivedTrackStatusRequest = newValue } }
    }

    private(set) var receivedFetchRequest: FetchRequest? {
        get { state.withLock { state in state.receivedFetchRequest } }
        set { state.withLock { state in state.receivedFetchRequest = newValue } }
    }

    private(set) var receivedFetchCancelRequestID: UInt64? {
        get { state.withLock { state in state.receivedFetchCancelRequestID } }
        set { state.withLock { state in state.receivedFetchCancelRequestID = newValue } }
    }

    private(set) var receivedPublishDone: PublishDone? {
        get { state.withLock { state in state.receivedPublishDone } }
        set { state.withLock { state in state.receivedPublishDone = newValue } }
    }

    private(set) var receivedPublishNamespaceDone: TrackNamespace? {
        get { state.withLock { state in state.receivedPublishNamespaceDone } }
        set { state.withLock { state in state.receivedPublishNamespaceDone = newValue } }
    }

    private(set) var receivedGoAwayURI: String? {
        get { state.withLock { state in state.receivedGoAwayURI } }
        set { state.withLock { state in state.receivedGoAwayURI = newValue } }
    }

    private(set) var receivedUnsubscribeNamespace: TrackNamespace? {
        get { state.withLock { state in state.receivedUnsubscribeNamespace } }
        set { state.withLock { state in state.receivedUnsubscribeNamespace = newValue } }
    }

    private(set) var receivedPublishNamespaceCancel: PublishNamespaceCancel? {
        get { state.withLock { state in state.receivedPublishNamespaceCancel } }
        set { state.withLock { state in state.receivedPublishNamespaceCancel = newValue } }
    }

    init() {
        self.state = Mutex<State>(State())
    }

    func session(
        _ session: Session,
        didReceiveSubscribeNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) async -> SubscribeNamespaceDecision {
        receivedSubscribeNamespace = prefix
        receivedSubscribeNamespaceAuthorizationToken = authorizationToken
        if let subscribeNamespaceError: SubscribeNamespaceRequestError = subscribeNamespaceError {
            return .reject(subscribeNamespaceError)
        }
        return .accept
    }

    func session(_ session: Session, didReceiveSubscribe publishedTrack: PublishedTrack) async -> SubscribeDecision {
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
    ) async -> PublishNamespaceDecision {
        receivedPublishNamespace = prefix
        receivedPublishNamespaceAuthorizationToken = authorizationToken
        if let publishNamespaceError: PublishNamespaceRequestError = publishNamespaceError {
            return .reject(publishNamespaceError)
        }
        return .accept
    }

    func session(_ session: Session, didReceivePublish resource: TrackResource) async -> PublishDecision {
        receivedPublishResource = resource
        if let publishError: PublishRequestError = publishError {
            return .reject(publishError)
        }
        return .accept(PublishAcceptance())
    }

    func session(_ session: Session, didReceiveSubscribeUpdate update: SubscribeUpdate) async {
        receivedSubscribeUpdate = update
    }

    func session(_ session: Session, didReceiveUnsubscribe requestID: UInt64) async {
        receivedUnsubscribeRequestID = requestID
    }

    func session(_ session: Session, didReceiveTrackStatus request: TrackStatusRequest) async -> TrackStatusDecision {
        receivedTrackStatusRequest = request
        if let trackStatusResult {
            return .accept(trackStatusResult)
        }
        return .reject(TrackStatusRequestError(code: .trackDoesNotExist, reason: "Track does not exist"))
    }

    func session(_ session: Session, didReceiveFetch request: FetchRequest) async -> FetchDecision {
        receivedFetchRequest = request
        if let fetchResponse {
            return .accept(fetchResponse)
        }
        return .reject(FetchRequestError(code: .trackDoesNotExist, reason: "Track does not exist"))
    }

    func session(_ session: Session, didReceiveFetchCancel requestID: UInt64) async {
        receivedFetchCancelRequestID = requestID
    }

    func session(_ session: Session, didReceivePublishDone publishDone: PublishDone) async {
        receivedPublishDone = publishDone
    }

    func session(_ session: Session, didReceivePublishNamespaceDone trackNamespace: TrackNamespace) async {
        receivedPublishNamespaceDone = trackNamespace
    }

    func session(_ session: Session, didReceiveGoAway newSessionURI: String?) async {
        receivedGoAwayURI = newSessionURI
    }

    func session(_ session: Session, didReceiveUnsubscribeNamespace namespacePrefix: TrackNamespace) async {
        receivedUnsubscribeNamespace = namespacePrefix
    }

    func session(_ session: Session, didReceivePublishNamespaceCancel cancellation: PublishNamespaceCancel) async {
        receivedPublishNamespaceCancel = cancellation
    }
}
