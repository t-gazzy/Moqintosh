//
//  DatagramReceiver.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Receives object datagrams for a subscribed track.
public actor DatagramReceiver {

    /// The subscription associated with this receiver.
    public nonisolated let subscription: Subscription
    private let stream: AsyncStream<ObjectDatagram>
    private let continuation: AsyncStream<ObjectDatagram>.Continuation

    init(sessionContext: SessionContext, subscription: Subscription) async {
        self.subscription = subscription
        let streamAndContinuation = AsyncStream<ObjectDatagram>.makeStream(bufferingPolicy: .bufferingNewest(256))
        self.stream = streamAndContinuation.stream
        self.continuation = streamAndContinuation.continuation
        sessionContext.datagramReceiverStore.register(trackAlias: subscription.publishedTrack.trackAlias) { [weak self] datagram in
            guard let self else { return }
            Task {
                await self.yield(datagram)
            }
        }
    }

    deinit {
        continuation.finish()
    }

    /// Waits for the next datagram, or returns nil when the receiver closes.
    public func receive() async -> ObjectDatagram? {
        var iterator: AsyncStream<ObjectDatagram>.Iterator = stream.makeAsyncIterator()
        return await iterator.next()
    }

    private func yield(_ datagram: ObjectDatagram) {
        switch continuation.yield(datagram) {
        case .enqueued:
            break
        case .dropped(let droppedDatagram):
            OSLogger.warn("Dropped OBJECT_DATAGRAM because DatagramReceiver buffer is full (trackAlias: \(droppedDatagram.trackAlias))")
        case .terminated:
            break
        @unknown default:
            break
        }
    }
}
