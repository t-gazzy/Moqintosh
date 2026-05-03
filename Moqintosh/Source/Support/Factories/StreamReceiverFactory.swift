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

    private let sessionContext: SessionContext
    private let queue: AsyncElementQueue<StreamReceiver>

    init(sessionContext: SessionContext, subscription: Subscription) async {
        self.sessionContext = sessionContext
        self.subscription = subscription
        self.queue = AsyncElementQueue<StreamReceiver>(bufferLimit: 256)
        await sessionContext.streamReceiverStore.register(trackAlias: subscription.publishedTrack.trackAlias) { [weak self] stream, header, initialData in
            guard let self else { return }
            let receiver: StreamReceiver = StreamReceiver(
                stream: stream,
                subscription: subscription,
                header: header,
                initialData: initialData
            )
            Task {
                await self.yield(receiver)
            }
        }
    }

    deinit {
        let queue: AsyncElementQueue<StreamReceiver> = self.queue
        Task {
            await queue.finish()
        }
    }

    /// Waits for the next inbound subgroup stream receiver.
    public func accept() async -> StreamReceiver? {
        await queue.next()
    }

    private func yield(_ receiver: StreamReceiver) async {
        let result: AsyncElementQueue<StreamReceiver>.EnqueueResult = await queue.enqueue(receiver)
        switch result {
        case .enqueued:
            break
        case .dropped:
            OSLogger.warn(
                "Dropped inbound stream receiver because StreamReceiverFactory buffer is full (trackAlias: \(receiver.header.trackAlias))"
            )
        case .terminated:
            OSLogger.debug(
                "Dropped inbound stream receiver because StreamReceiverFactory is terminated (trackAlias: \(receiver.header.trackAlias))"
            )
        @unknown default:
            OSLogger.warn(
                "Dropped inbound stream receiver for an unknown reason (trackAlias: \(receiver.header.trackAlias))"
            )
        }
    }

}

private actor AsyncElementQueue<Element: Sendable> {

    enum EnqueueResult {
        case enqueued
        case dropped
        case terminated
    }

    private let bufferLimit: Int
    private var elements: [Element]
    private var waiters: [CheckedContinuation<Element?, Never>]
    private var isFinished: Bool

    init(bufferLimit: Int) {
        self.bufferLimit = bufferLimit
        self.elements = []
        self.waiters = []
        self.isFinished = false
    }

    func enqueue(_ element: Element) -> EnqueueResult {
        if isFinished {
            return .terminated
        }
        if let waiter: CheckedContinuation<Element?, Never> = waiters.first {
            waiters.removeFirst()
            waiter.resume(returning: element)
            return .enqueued
        }
        if elements.count >= bufferLimit {
            return .dropped
        }
        elements.append(element)
        return .enqueued
    }

    func next() async -> Element? {
        if !elements.isEmpty {
            return elements.removeFirst()
        }
        if isFinished {
            return nil
        }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func finish() {
        isFinished = true
        let pendingWaiters: [CheckedContinuation<Element?, Never>] = waiters
        waiters.removeAll()
        for waiter: CheckedContinuation<Element?, Never> in pendingWaiters {
            waiter.resume(returning: nil)
        }
    }
}
