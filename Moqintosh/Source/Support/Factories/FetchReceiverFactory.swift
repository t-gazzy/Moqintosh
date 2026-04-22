//
//  FetchReceiverFactory.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation
import Synchronization

// Safe because shared mutable receiver storage is protected by Mutex and continuations are thread-safe.
/// Creates fetch receivers for inbound fetch streams.
public final class FetchReceiverFactory: @unchecked Sendable {

    /// The fetch receivers created for inbound fetch streams.
    public let receivers: AsyncStream<FetchReceiver>
    /// The fetch subscription associated with receivers created by this factory.
    public let fetchSubscription: FetchSubscription

    private let receiverContinuation: AsyncStream<FetchReceiver>.Continuation
    private let activeReceivers: Mutex<[ObjectIdentifier: FetchReceiver]>

    init(sessionContext: SessionContext, fetchSubscription: FetchSubscription) {
        let receiverStream: (
            stream: AsyncStream<FetchReceiver>,
            continuation: AsyncStream<FetchReceiver>.Continuation
        ) = FetchReceiverFactory.makeReceiverStream()
        self.receivers = receiverStream.stream
        self.fetchSubscription = fetchSubscription
        self.receiverContinuation = receiverStream.continuation
        self.activeReceivers = Mutex<[ObjectIdentifier: FetchReceiver]>([:])
        sessionContext.fetchReceiverStore.register(requestID: fetchSubscription.requestID) { [weak self] stream, _, initialData in
            guard let self else { return }
            let receiver: FetchReceiver = FetchReceiver(
                stream: stream,
                fetchSubscription: fetchSubscription,
                initialData: initialData
            )
            let receiverID: ObjectIdentifier = ObjectIdentifier(receiver)
            receiver.onClose = { [weak self] receiver in
                self?.removeActiveReceiver(receiver)
            }
            self.activeReceivers.withLock { activeReceivers in
                activeReceivers[receiverID] = receiver
            }
            self.receiverContinuation.yield(receiver)
            receiver.start()
        }
    }

    deinit {
        receiverContinuation.finish()
    }

    private func removeActiveReceiver(_ receiver: FetchReceiver) {
        _ = activeReceivers.withLock { activeReceivers in
            activeReceivers.removeValue(forKey: ObjectIdentifier(receiver))
        }
    }

    private static func makeReceiverStream() -> (
        stream: AsyncStream<FetchReceiver>,
        continuation: AsyncStream<FetchReceiver>.Continuation
    ) {
        var streamContinuation: AsyncStream<FetchReceiver>.Continuation?
        let stream: AsyncStream<FetchReceiver> = AsyncStream<FetchReceiver> { continuation in
            streamContinuation = continuation
        }
        guard let streamContinuation else {
            preconditionFailure("AsyncStream must create a continuation")
        }
        return (stream, streamContinuation)
    }
}
