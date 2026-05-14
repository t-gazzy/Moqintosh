//
//  StreamReceiverFactory.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Creates stream receivers for inbound subgroup streams on a subscription.
public actor StreamReceiverFactory {

    /// The subscription associated with receivers created by this factory.
    public nonisolated let subscription: Subscription

    private let stream: AsyncStream<StreamReceiver>
    private let continuation: AsyncStream<StreamReceiver>.Continuation

    init(sessionContext: SessionContext, subscription: Subscription) async {
        self.subscription = subscription
        let streamAndContinuation = AsyncStream<StreamReceiver>.makeStream(bufferingPolicy: .bufferingOldest(256))
        self.stream = streamAndContinuation.stream
        self.continuation = streamAndContinuation.continuation
        await sessionContext.streamReceiverStore.register(trackAlias: subscription.publishedTrack.trackAlias) { [weak self] stream, header, initialData in
            guard let self else { return }
            let receiver: StreamReceiver = StreamReceiver(
                stream: stream,
                header: header,
                initialData: initialData
            )
            Task {
                await self.yield(receiver)
            }
        }
    }

    deinit {
        continuation.finish()
    }

    /// Waits for the next inbound subgroup stream receiver.
    public func accept() async -> StreamReceiver? {
        var iterator: AsyncStream<StreamReceiver>.Iterator = stream.makeAsyncIterator()
        return await iterator.next()
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
