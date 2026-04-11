//
//  SessionContext.swift
//  Moqintosh
//
//  Created by Takemasa Kaji on 2026/04/10.
//

import Foundation

final class SessionContext {

    weak var session: Session?

    let connection: TransportConnection
    let controlStream: TransportBiStream
    let requestStore: SessionRequestStore
    let streamReceiverStore: StreamReceiverStore
    let datagramReceiverStore: DatagramReceiverStore
    /// Client-side Request IDs start at 0 and increment by 2 (even numbers, Section 9.1).
    private var nextRequestID: UInt64 = 0
    private var nextTrackAlias: UInt64 = 0
    private var remoteMaxRequestID: UInt64
    private var blockedRequestID: UInt64?
    private let stateQueue: DispatchQueue

    init(connection: TransportConnection, controlStream: TransportBiStream, remoteMaxRequestID: UInt64 = 0) {
        self.connection = connection
        self.controlStream = controlStream
        self.requestStore = SessionRequestStore()
        self.streamReceiverStore = StreamReceiverStore()
        self.datagramReceiverStore = DatagramReceiverStore()
        self.remoteMaxRequestID = remoteMaxRequestID
        self.blockedRequestID = nil
        self.stateQueue = DispatchQueue(label: "Moqintosh.SessionContext")
    }

    // MARK: - Request ID

    /// Issues the next Request ID and advances the counter.
    func issueRequestID() async throws -> UInt64 {
        let result: (id: UInt64?, blockedRequestID: UInt64?) = stateQueue.sync {
            let id: UInt64 = nextRequestID
            guard id <= remoteMaxRequestID else {
                let messageRequestID: UInt64? = blockedRequestID == remoteMaxRequestID ? nil : remoteMaxRequestID
                blockedRequestID = remoteMaxRequestID
                return (nil, messageRequestID)
            }
            nextRequestID += 2
            return (id, nil)
        }
        if let id: UInt64 = result.id {
            return id
        }
        if let blockedRequestID: UInt64 = result.blockedRequestID {
            let message: RequestsBlockedMessage = .init(requestID: blockedRequestID)
            OSLogger.debug("Sending REQUESTS_BLOCKED (requestID: \(blockedRequestID))")
            try await controlStream.send(bytes: message.encode())
        }
        throw SessionFlowControlError.blocked(maxRequestID: stateQueue.sync { remoteMaxRequestID })
    }

    func issueTrackAlias() -> UInt64 {
        stateQueue.sync {
            let alias: UInt64 = nextTrackAlias
            nextTrackAlias += 1
            return alias
        }
    }

    func updateRemoteMaxRequestID(_ requestID: UInt64) {
        stateQueue.sync {
            guard requestID > remoteMaxRequestID else {
                return
            }
            remoteMaxRequestID = requestID
            if let blockedRequestID, blockedRequestID < requestID {
                self.blockedRequestID = nil
            }
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
}
