//
//  FetchReceiverFactory.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

/// Creates fetch receivers for inbound fetch streams.
public actor FetchReceiverFactory {

    /// The fetch subscription associated with receivers created by this factory.
    public nonisolated let fetchSubscription: FetchSubscription

    private let stream: AsyncStream<FetchReceiver>
    private let continuation: AsyncStream<FetchReceiver>.Continuation

    init(sessionContext: SessionContext, fetchSubscription: FetchSubscription) async {
        self.fetchSubscription = fetchSubscription
        let streamAndContinuation = AsyncStream<FetchReceiver>.makeStream(bufferingPolicy: .bufferingOldest(256))
        self.stream = streamAndContinuation.stream
        self.continuation = streamAndContinuation.continuation
        await sessionContext.fetchReceiverStore.register(requestID: fetchSubscription.requestID) { [weak self] stream, _, initialData in
            guard let self else { return }
            let receiver: FetchReceiver = FetchReceiver(
                stream: stream,
                fetchSubscription: fetchSubscription,
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

    /// Waits for the next inbound fetch stream receiver.
    public func accept() async -> FetchReceiver? {
        var iterator: AsyncStream<FetchReceiver>.Iterator = stream.makeAsyncIterator()
        return await iterator.next()
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
