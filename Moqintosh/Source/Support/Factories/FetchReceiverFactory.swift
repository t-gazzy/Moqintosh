//
//  FetchReceiverFactory.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

/// Creates fetch receivers for inbound fetch streams.
public final class FetchReceiverFactory: Sendable {

    /// The fetch subscription associated with receivers created by this factory.
    public let fetchSubscription: FetchSubscription

    /// Inbound fetch stream receivers. Iterate this stream from a single consumer.
    public let receivers: AsyncStream<FetchReceiver>
    private let continuation: AsyncStream<FetchReceiver>.Continuation

    init(sessionContext: SessionContext, fetchSubscription: FetchSubscription) async {
        self.fetchSubscription = fetchSubscription
        let streamAndContinuation: (
            stream: AsyncStream<FetchReceiver>,
            continuation: AsyncStream<FetchReceiver>.Continuation
        ) = AsyncStream<FetchReceiver>.makeStream(bufferingPolicy: .bufferingOldest(256))
        self.receivers = streamAndContinuation.stream
        self.continuation = streamAndContinuation.continuation
        await sessionContext.fetchReceiverStore.register(requestID: fetchSubscription.requestID) { [weak self] stream, _, initialData in
            let receiver: FetchReceiver = FetchReceiver(
                stream: stream,
                fetchSubscription: fetchSubscription,
                initialData: initialData
            )
            self?.yield(receiver)
        }
    }

    deinit {
        continuation.finish()
    }

    private func yield(_ receiver: FetchReceiver) {
        switch continuation.yield(receiver) {
        case .enqueued:
            break
        case .dropped(let droppedReceiver):
            OSLogger.warn(
                "Dropped inbound fetch receiver because FetchReceiverFactory buffer is full (requestID: \(droppedReceiver.fetchSubscription.requestID))"
            )
        case .terminated:
            break
        @unknown default:
            break
        }
    }

}
