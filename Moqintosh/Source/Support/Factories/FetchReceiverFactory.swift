//
//  FetchReceiverFactory.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

// Safe because accept() is intended for app-owned consumption and receiver delivery uses AsyncStream.
/// Creates fetch receivers for inbound fetch streams.
public final class FetchReceiverFactory: @unchecked Sendable {

    /// The fetch subscription associated with receivers created by this factory.
    public let fetchSubscription: FetchSubscription

    private let receiverContinuation: AsyncStream<FetchReceiver>.Continuation
    private var receiverIterator: AsyncStream<FetchReceiver>.Iterator

    init(sessionContext: SessionContext, fetchSubscription: FetchSubscription) {
        let receiverStream: (
            stream: AsyncStream<FetchReceiver>,
            continuation: AsyncStream<FetchReceiver>.Continuation
        ) = FetchReceiverFactory.makeReceiverStream()
        self.fetchSubscription = fetchSubscription
        self.receiverContinuation = receiverStream.continuation
        self.receiverIterator = receiverStream.stream.makeAsyncIterator()
        sessionContext.fetchReceiverStore.register(requestID: fetchSubscription.requestID) { [weak self] stream, _, initialData in
            guard let self else { return }
            let receiver: FetchReceiver = FetchReceiver(
                stream: stream,
                fetchSubscription: fetchSubscription,
                initialData: initialData
            )
            self.yield(receiver)
        }
    }

    deinit {
        receiverContinuation.finish()
    }

    /// Waits for the next inbound fetch stream receiver.
    public func accept() async -> FetchReceiver? {
        await receiverIterator.next()
    }

    private func yield(_ receiver: FetchReceiver) {
        let result: AsyncStream<FetchReceiver>.Continuation.YieldResult = receiverContinuation.yield(receiver)
        switch result {
        case .enqueued:
            break
        case .dropped:
            OSLogger.warn(
                "Dropped inbound fetch receiver because FetchReceiverFactory buffer is full (requestID: \(receiver.fetchSubscription.requestID))"
            )
        case .terminated:
            OSLogger.debug(
                "Dropped inbound fetch receiver because FetchReceiverFactory is terminated (requestID: \(receiver.fetchSubscription.requestID))"
            )
        @unknown default:
            OSLogger.warn(
                "Dropped inbound fetch receiver for an unknown reason (requestID: \(receiver.fetchSubscription.requestID))"
            )
        }
    }

    private static func makeReceiverStream() -> (
        stream: AsyncStream<FetchReceiver>,
        continuation: AsyncStream<FetchReceiver>.Continuation
    ) {
        var streamContinuation: AsyncStream<FetchReceiver>.Continuation?
        let stream: AsyncStream<FetchReceiver> = AsyncStream<FetchReceiver>(
            bufferingPolicy: .bufferingOldest(256)
        ) { continuation in
            streamContinuation = continuation
        }
        guard let streamContinuation else {
            preconditionFailure("AsyncStream must create a continuation")
        }
        return (stream, streamContinuation)
    }
}
