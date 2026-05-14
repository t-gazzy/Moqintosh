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

    private let queue: AsyncElementQueue<FetchReceiver>

    init(sessionContext: SessionContext, fetchSubscription: FetchSubscription) async {
        self.fetchSubscription = fetchSubscription
        self.queue = AsyncElementQueue<FetchReceiver>(bufferLimit: 256)
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
        let queue: AsyncElementQueue<FetchReceiver> = self.queue
        Task {
            await queue.finish()
        }
    }

    /// Waits for the next inbound fetch stream receiver.
    public func accept() async -> FetchReceiver? {
        await queue.next()
    }

    private func yield(_ receiver: FetchReceiver) async {
        let result: AsyncElementQueue<FetchReceiver>.EnqueueResult = await queue.enqueue(receiver)
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

}

private actor AsyncElementQueue<Element: Sendable> {

    private struct Waiter {
        let id: UInt64
        let continuation: CheckedContinuation<Element?, Never>
    }

    enum EnqueueResult {
        case enqueued
        case dropped
        case terminated
    }

    private let bufferLimit: Int
    private var elements: [Element]
    private var waiters: [Waiter]
    private var cancelledWaiterIDs: Set<UInt64>
    private var nextWaiterID: UInt64
    private var isFinished: Bool

    init(bufferLimit: Int) {
        self.bufferLimit = bufferLimit
        self.elements = []
        self.waiters = []
        self.cancelledWaiterIDs = []
        self.nextWaiterID = 0
        self.isFinished = false
    }

    func enqueue(_ element: Element) -> EnqueueResult {
        if isFinished {
            return .terminated
        }
        if let waiter: Waiter = waiters.first {
            waiters.removeFirst()
            waiter.continuation.resume(returning: element)
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

        let waiterID: UInt64 = nextWaiterID
        nextWaiterID += 1
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled || cancelledWaiterIDs.remove(waiterID) != nil {
                    continuation.resume(returning: nil)
                    return
                }
                waiters.append(Waiter(id: waiterID, continuation: continuation))
            }
        } onCancel: {
            Task {
                await self.cancelWaiter(id: waiterID)
            }
        }
    }

    func finish() {
        isFinished = true
        let pendingWaiters: [Waiter] = waiters
        waiters.removeAll()
        for waiter: Waiter in pendingWaiters {
            waiter.continuation.resume(returning: nil)
        }
    }

    private func cancelWaiter(id: UInt64) {
        guard let index: Int = waiters.firstIndex(where: { $0.id == id }) else {
            cancelledWaiterIDs.insert(id)
            return
        }
        let waiter: Waiter = waiters.remove(at: index)
        waiter.continuation.resume(returning: nil)
    }
}
