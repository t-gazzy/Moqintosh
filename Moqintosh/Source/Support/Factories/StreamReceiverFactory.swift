//
//  StreamReceiverFactory.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Synchronization

/// Creates stream receivers for inbound subgroup streams on a subscription.
public final class StreamReceiverFactory: @unchecked Sendable {

    /// The stream receivers created for inbound subgroup streams.
    public let receivers: AsyncStream<StreamReceiver>
    /// The subscription associated with receivers created by this factory.
    public let subscription: Subscription

    private let sessionContext: SessionContext
    private let receiverContinuation: AsyncStream<StreamReceiver>.Continuation
    private let activeReceivers: Mutex<[ObjectIdentifier: StreamReceiver]>

    init(sessionContext: SessionContext, subscription: Subscription) {
        let receiverStream: (
            stream: AsyncStream<StreamReceiver>,
            continuation: AsyncStream<StreamReceiver>.Continuation
        ) = StreamReceiverFactory.makeReceiverStream()
        self.receivers = receiverStream.stream
        self.sessionContext = sessionContext
        self.subscription = subscription
        self.receiverContinuation = receiverStream.continuation
        self.activeReceivers = Mutex<[ObjectIdentifier: StreamReceiver]>([:])
        sessionContext.streamReceiverStore.register(trackAlias: subscription.publishedTrack.trackAlias) { [weak self] stream, header, initialData in
            guard let self else { return }
            let receiver: StreamReceiver = StreamReceiver(
                stream: stream,
                subscription: subscription,
                header: header,
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

    private func removeActiveReceiver(_ receiver: StreamReceiver) {
        _ = activeReceivers.withLock { activeReceivers in
            activeReceivers.removeValue(forKey: ObjectIdentifier(receiver))
        }
    }

    private static func makeReceiverStream() -> (
        stream: AsyncStream<StreamReceiver>,
        continuation: AsyncStream<StreamReceiver>.Continuation
    ) {
        var streamContinuation: AsyncStream<StreamReceiver>.Continuation?
        let stream: AsyncStream<StreamReceiver> = AsyncStream<StreamReceiver> { continuation in
            streamContinuation = continuation
        }
        guard let streamContinuation else {
            preconditionFailure("AsyncStream must create a continuation")
        }
        return (stream, streamContinuation)
    }
}
