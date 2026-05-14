//
//  DatagramReceiver.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Receives object datagrams for a subscribed track.
public actor DatagramReceiver {

    private enum EnqueueResult {
        case enqueued
        case dropped
        case terminated
    }

    private struct Waiter {
        let id: UInt64
        let continuation: CheckedContinuation<ObjectDatagram?, Never>
    }

    /// The subscription associated with this receiver.
    public nonisolated let subscription: Subscription
    private let bufferLimit: Int
    private var datagrams: [ObjectDatagram]
    private var waiters: [Waiter]
    private var cancelledWaiterIDs: Set<UInt64>
    private var nextWaiterID: UInt64
    private var isFinished: Bool

    init(sessionContext: SessionContext, subscription: Subscription) async {
        self.subscription = subscription
        self.bufferLimit = 256
        self.datagrams = []
        self.waiters = []
        self.cancelledWaiterIDs = []
        self.nextWaiterID = 0
        self.isFinished = false
        sessionContext.datagramReceiverStore.register(trackAlias: subscription.publishedTrack.trackAlias) { [weak self] datagram in
            guard let self else { return }
            Task {
                await self.yield(datagram)
            }
        }
    }

    deinit {
        for waiter: Waiter in waiters {
            waiter.continuation.resume(returning: nil)
        }
    }

    /// Waits for the next datagram, or returns nil when the receiver closes.
    public func receive() async -> ObjectDatagram? {
        if !datagrams.isEmpty {
            return datagrams.removeFirst()
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

    private func yield(_ datagram: ObjectDatagram) {
        let result: EnqueueResult = enqueue(datagram)
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

    private func enqueue(_ datagram: ObjectDatagram) -> EnqueueResult {
        if isFinished {
            return .terminated
        }
        if let waiter: Waiter = waiters.first {
            waiters.removeFirst()
            waiter.continuation.resume(returning: datagram)
            return .enqueued
        }
        if datagrams.count >= bufferLimit {
            _ = datagrams.removeFirst()
            datagrams.append(datagram)
            return .dropped
        }
        datagrams.append(datagram)
        return .enqueued
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
