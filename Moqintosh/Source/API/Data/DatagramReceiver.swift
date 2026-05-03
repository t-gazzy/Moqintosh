//
//  DatagramReceiver.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Receives object datagrams for a subscribed track.
public final class DatagramReceiver: Sendable {

    /// The subscription associated with this receiver.
    public let subscription: Subscription
    private let queue: AsyncElementQueue<ObjectDatagram>

    init(sessionContext: SessionContext, subscription: Subscription) async {
        self.subscription = subscription
        self.queue = AsyncElementQueue<ObjectDatagram>(bufferLimit: 256)
        sessionContext.datagramReceiverStore.register(trackAlias: subscription.publishedTrack.trackAlias) { [weak self] datagram in
            guard let self else { return }
            Task {
                await self.yield(datagram)
            }
        }
    }

    deinit {
        let queue: AsyncElementQueue<ObjectDatagram> = self.queue
        Task {
            await queue.finish()
        }
    }

    /// Waits for the next datagram, or returns nil when the receiver closes.
    public func receive() async -> ObjectDatagram? {
        await queue.next()
    }

    private func yield(_ datagram: ObjectDatagram) async {
        let result: AsyncElementQueue<ObjectDatagram>.EnqueueResult = await queue.enqueue(datagram)
        switch result {
        case .enqueued:
            break
        case .dropped:
            OSLogger.warn("Dropped OBJECT_DATAGRAM because DatagramReceiver buffer is full (trackAlias: \(datagram.trackAlias))")
        case .terminated:
            OSLogger.debug("Dropped OBJECT_DATAGRAM because DatagramReceiver is terminated (trackAlias: \(datagram.trackAlias))")
        @unknown default:
            OSLogger.warn("Dropped OBJECT_DATAGRAM for an unknown reason (trackAlias: \(datagram.trackAlias))")
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
            _ = elements.removeFirst()
            elements.append(element)
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
