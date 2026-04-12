//
//  SessionContext.swift
//  Moqintosh
//
//  Created by Takemasa Kaji on 2026/04/10.
//

import Foundation
import Synchronization

// Safe because mutable session state is serialized through state and request stores own their own synchronization.
final class SessionContext: @unchecked Sendable {

    private struct State {
        var nextRequestID: UInt64
        var nextTrackAlias: UInt64
        var remoteMaxRequestID: UInt64
        var blockedRequestID: UInt64?
        var inboundSubscriptionResources: [UInt64: TrackResource]
    }

    weak var session: Session?

    let connection: TransportConnection
    let controlStream: TransportBiStream
    let requestStore: SessionRequestStore
    let streamReceiverStore: StreamReceiverStore
    let fetchReceiverStore: FetchReceiverStore
    let datagramReceiverStore: DatagramReceiverStore
    private let state: Mutex<State>

    init(connection: TransportConnection, controlStream: TransportBiStream, remoteMaxRequestID: UInt64 = 0) {
        self.connection = connection
        self.controlStream = controlStream
        self.requestStore = SessionRequestStore()
        self.streamReceiverStore = StreamReceiverStore()
        self.fetchReceiverStore = FetchReceiverStore()
        self.datagramReceiverStore = DatagramReceiverStore()
        self.state = Mutex<State>(
            State(
                nextRequestID: 0,
                nextTrackAlias: 0,
                remoteMaxRequestID: remoteMaxRequestID,
                blockedRequestID: nil,
                inboundSubscriptionResources: [:]
            )
        )
    }

    // MARK: - Request ID

    /// Issues the next Request ID and advances the counter.
    func issueRequestID() async throws -> UInt64 {
        let result: (id: UInt64?, blockedRequestID: UInt64?, maxRequestID: UInt64) = state.withLock { state in
            let id: UInt64 = state.nextRequestID
            guard id <= state.remoteMaxRequestID else {
                let messageRequestID: UInt64? = state.blockedRequestID == state.remoteMaxRequestID ? nil : state.remoteMaxRequestID
                state.blockedRequestID = state.remoteMaxRequestID
                return (nil, messageRequestID, state.remoteMaxRequestID)
            }
            state.nextRequestID += 2
            return (id, nil, state.remoteMaxRequestID)
        }
        if let id: UInt64 = result.id {
            return id
        }
        if let blockedRequestID: UInt64 = result.blockedRequestID {
            let message: RequestsBlockedMessage = RequestsBlockedMessage(requestID: blockedRequestID)
            OSLogger.debug("Sending REQUESTS_BLOCKED (requestID: \(blockedRequestID))")
            try await controlStream.send(bytes: message.encode())
        }
        throw SessionFlowControlError.blocked(maxRequestID: result.maxRequestID)
    }

    func issueTrackAlias() -> UInt64 {
        state.withLock { state in
            let alias: UInt64 = state.nextTrackAlias
            state.nextTrackAlias += 1
            return alias
        }
    }

    func updateRemoteMaxRequestID(_ requestID: UInt64) {
        state.withLock { state in
            guard requestID > state.remoteMaxRequestID else {
                return
            }
            state.remoteMaxRequestID = requestID
            if let blockedRequestID: UInt64 = state.blockedRequestID, blockedRequestID < requestID {
                state.blockedRequestID = nil
            }
        }
    }

    func registerInboundSubscriptionResource(requestID: UInt64, resource: TrackResource) {
        state.withLock { state in
            state.inboundSubscriptionResources[requestID] = resource
        }
    }

    func inboundSubscriptionResource(for requestID: UInt64) -> TrackResource? {
        state.withLock { state in
            state.inboundSubscriptionResources[requestID]
        }
    }

    func removeInboundSubscriptionResource(requestID: UInt64) {
        state.withLock { state in
            _ = state.inboundSubscriptionResources.removeValue(forKey: requestID)
        }
    }
}

extension SessionContext: ControlMessageChannel {
    func sendControlMessage(bytes: Data) async throws {
        try await controlStream.send(bytes: bytes)
    }

    func performPublishNamespaceRequest(requestID: UInt64, bytes: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            requestStore.addRequest(requestID, continuation: continuation)
            Task {
                do {
                    try await self.controlStream.send(bytes: bytes)
                } catch {
                    self.requestStore.failRequest(requestID, error: error)
                }
            }
        }
    }

    func performPublishRequest(requestID: UInt64, publishedTrack: PublishedTrack, bytes: Data) async throws -> PublishedTrack {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PublishedTrack, Error>) in
            requestStore.addPublishRequest(requestID, publishedTrack: publishedTrack, continuation: continuation)
            Task {
                do {
                    try await self.controlStream.send(bytes: bytes)
                } catch {
                    self.requestStore.failPublishRequest(requestID, error: error)
                }
            }
        }
    }

    func performSubscribeNamespaceRequest(requestID: UInt64, bytes: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            requestStore.addRequest(requestID, continuation: continuation)
            Task {
                do {
                    try await self.controlStream.send(bytes: bytes)
                } catch {
                    self.requestStore.failRequest(requestID, error: error)
                }
            }
        }
    }

    func performSubscribeRequest(
        requestID: UInt64,
        resource: TrackResource,
        subscriberPriority: UInt8,
        requestedGroupOrder: GroupOrder,
        forward: Bool,
        filter: SubscriptionFilter,
        bytes: Data
    ) async throws -> Subscription {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Subscription, Error>) in
            requestStore.addSubscribeRequest(
                requestID,
                resource: resource,
                subscriberPriority: subscriberPriority,
                requestedGroupOrder: requestedGroupOrder,
                forward: forward,
                filter: filter,
                continuation: continuation
            )
            Task {
                do {
                    try await self.controlStream.send(bytes: bytes)
                } catch {
                    self.requestStore.failSubscribeRequest(requestID, error: error)
                }
            }
        }
    }

    func performTrackStatusRequest(requestID: UInt64, bytes: Data) async throws -> TrackStatus {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TrackStatus, Error>) in
            requestStore.addTrackStatusRequest(requestID, continuation: continuation)
            Task {
                do {
                    try await self.controlStream.send(bytes: bytes)
                } catch {
                    self.requestStore.failTrackStatusRequest(requestID, error: error)
                }
            }
        }
    }

    func performFetchRequest(
        requestID: UInt64,
        resource: TrackResource,
        subscriberPriority: UInt8,
        bytes: Data
    ) async throws -> FetchSubscription {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<FetchSubscription, Error>) in
            requestStore.addFetchRequest(
                requestID,
                resource: resource,
                subscriberPriority: subscriberPriority,
                continuation: continuation
            )
            Task {
                do {
                    try await self.controlStream.send(bytes: bytes)
                } catch {
                    self.requestStore.failFetchRequest(requestID, error: error)
                }
            }
        }
    }
}
