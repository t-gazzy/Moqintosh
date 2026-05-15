//
//  StreamReceiverFactory.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Creates stream receivers for inbound subgroup streams on a subscription.
public final class StreamReceiverFactory: Sendable {

    /// The subscription associated with receivers created by this factory.
    public let subscription: Subscription

    /// Inbound subgroup stream receivers. Iterate this stream from a single consumer.
    public let receivers: AsyncStream<StreamReceiver>
    private let continuation: AsyncStream<StreamReceiver>.Continuation

    init(sessionContext: SessionContext, subscription: Subscription) async {
        self.subscription = subscription
        let streamAndContinuation: (
            stream: AsyncStream<StreamReceiver>,
            continuation: AsyncStream<StreamReceiver>.Continuation
        ) = AsyncStream<StreamReceiver>.makeStream(bufferingPolicy: .bufferingOldest(256))
        self.receivers = streamAndContinuation.stream
        self.continuation = streamAndContinuation.continuation
        await sessionContext.streamReceiverStore.register(trackAlias: subscription.publishedTrack.trackAlias) { [weak self] stream, header, initialData in
            let receiver: StreamReceiver = StreamReceiver(
                stream: stream,
                header: header,
                initialData: initialData
            )
            self?.yield(receiver)
        }
    }

    deinit {
        continuation.finish()
    }

    private func yield(_ receiver: StreamReceiver) {
        switch continuation.yield(receiver) {
        case .enqueued:
            break
        case .dropped(let droppedReceiver):
            OSLogger.warn(
                "Dropped inbound stream receiver because StreamReceiverFactory buffer is full (trackAlias: \(droppedReceiver.header.trackAlias))"
            )
        case .terminated:
            break
        @unknown default:
            break
        }
    }

}
