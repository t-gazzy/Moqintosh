//
//  SessionContext.swift
//  Moqintosh
//
//  Created by Takemasa Kaji on 2026/04/10.
//

import Foundation

actor SessionContext {

    private struct State {
        var nextRequestID: UInt64
        var nextTrackAlias: UInt64
        var remoteMaxRequestID: UInt64
        var blockedRequestID: UInt64?
        var inboundSubscriptionResources: [UInt64: TrackResource]
    }

    private weak var session: Session?

    private let connection: TransportConnection
    private let controlStream: TransportBiStream
    nonisolated let requestStore: SessionRequestStore
    nonisolated let streamReceiverStore: StreamReceiverStore
    nonisolated let fetchReceiverStore: FetchReceiverStore
    nonisolated let datagramReceiverStore: DatagramReceiverStore
    private var state: State

    init(connection: TransportConnection, controlStream: TransportBiStream, remoteMaxRequestID: UInt64 = 0) {
        self.connection = connection
        self.controlStream = controlStream
        self.requestStore = SessionRequestStore()
        self.streamReceiverStore = StreamReceiverStore()
        self.fetchReceiverStore = FetchReceiverStore()
        self.datagramReceiverStore = DatagramReceiverStore()
        self.state = State(
            nextRequestID: 0,
            nextTrackAlias: 0,
            remoteMaxRequestID: remoteMaxRequestID,
            blockedRequestID: nil,
            inboundSubscriptionResources: [:]
        )
    }

    // MARK: - Request ID

    /// Issues the next Request ID and advances the counter.
    func issueRequestID() async throws -> UInt64 {
        let id: UInt64 = state.nextRequestID
        let result: (id: UInt64?, blockedRequestID: UInt64?, maxRequestID: UInt64)
        if id <= state.remoteMaxRequestID {
            state.nextRequestID += 2
            result = (id, nil, state.remoteMaxRequestID)
        } else {
            let messageRequestID: UInt64? = state.blockedRequestID == state.remoteMaxRequestID ? nil : state.remoteMaxRequestID
            state.blockedRequestID = state.remoteMaxRequestID
            result = (nil, messageRequestID, state.remoteMaxRequestID)
        }
        if let issuedID: UInt64 = result.id {
            return issuedID
        }
        if let blockedRequestID: UInt64 = result.blockedRequestID {
            let message: RequestsBlockedMessage = RequestsBlockedMessage(requestID: blockedRequestID)
            OSLogger.debug("Sending REQUESTS_BLOCKED (requestID: \(blockedRequestID))")
            try await controlStream.send(bytes: message.encode())
        }
        throw SessionFlowControlError.blocked(maxRequestID: result.maxRequestID)
    }

    func issueTrackAlias() -> UInt64 {
        let alias: UInt64 = state.nextTrackAlias
        state.nextTrackAlias += 1
        return alias
    }

    func updateRemoteMaxRequestID(_ requestID: UInt64) {
        guard requestID > state.remoteMaxRequestID else {
            return
        }
        state.remoteMaxRequestID = requestID
        if let blockedRequestID: UInt64 = state.blockedRequestID, blockedRequestID < requestID {
            state.blockedRequestID = nil
        }
    }

    func registerInboundSubscriptionResource(requestID: UInt64, resource: TrackResource) {
        state.inboundSubscriptionResources[requestID] = resource
    }

    func inboundSubscriptionResource(for requestID: UInt64) -> TrackResource? {
        state.inboundSubscriptionResources[requestID]
    }

    func removeInboundSubscriptionResource(requestID: UInt64) {
        _ = state.inboundSubscriptionResources.removeValue(forKey: requestID)
    }

    func openUniStream() async throws -> TransportUniSendStream {
        try await connection.openUniStream()
    }

    func sendDatagram(bytes: Data) async throws {
        try await connection.sendDatagram(bytes: bytes)
    }

    func setSession(_ session: Session) {
        self.session = session
    }

    func currentSession() -> Session? {
        session
    }

    func setConnectionDelegate(_ delegate: any TransportConnectionDelegate) {
        connection.delegate = delegate
    }
}

extension SessionContext: ControlMessageChannel {
    func sendControlMessage(bytes: Data) async throws {
        try await controlStream.send(bytes: bytes)
    }

    func performPublishNamespaceRequest(requestID: UInt64, bytes: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task {
                await requestStore.addRequest(requestID, continuation: continuation)
            }
            Task {
                do {
                    try await self.controlStream.send(bytes: bytes)
                } catch {
                    await self.requestStore.failRequest(requestID, error: error)
                }
            }
        }
    }

    func performPublishRequest(requestID: UInt64, publishedTrack: PublishedTrack, bytes: Data) async throws -> PublishedTrack {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PublishedTrack, Error>) in
            Task {
                await requestStore.addPublishRequest(requestID, publishedTrack: publishedTrack, continuation: continuation)
            }
            Task {
                do {
                    try await self.controlStream.send(bytes: bytes)
                } catch {
                    await self.requestStore.failPublishRequest(requestID, error: error)
                }
            }
        }
    }

    func performSubscribeNamespaceRequest(requestID: UInt64, bytes: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task {
                await requestStore.addRequest(requestID, continuation: continuation)
            }
            Task {
                do {
                    try await self.controlStream.send(bytes: bytes)
                } catch {
                    await self.requestStore.failRequest(requestID, error: error)
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
            Task {
                await requestStore.addSubscribeRequest(
                    requestID,
                    resource: resource,
                    subscriberPriority: subscriberPriority,
                    requestedGroupOrder: requestedGroupOrder,
                    forward: forward,
                    filter: filter,
                    continuation: continuation
                )
            }
            Task {
                do {
                    try await self.controlStream.send(bytes: bytes)
                } catch {
                    await self.requestStore.failSubscribeRequest(requestID, error: error)
                }
            }
        }
    }

    func performTrackStatusRequest(requestID: UInt64, bytes: Data) async throws -> TrackStatus {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TrackStatus, Error>) in
            Task {
                await requestStore.addTrackStatusRequest(requestID, continuation: continuation)
            }
            Task {
                do {
                    try await self.controlStream.send(bytes: bytes)
                } catch {
                    await self.requestStore.failTrackStatusRequest(requestID, error: error)
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
            Task {
                await requestStore.addFetchRequest(
                    requestID,
                    resource: resource,
                    subscriberPriority: subscriberPriority,
                    continuation: continuation
                )
            }
            Task {
                do {
                    try await self.controlStream.send(bytes: bytes)
                } catch {
                    await self.requestStore.failFetchRequest(requestID, error: error)
                }
            }
        }
    }
}
