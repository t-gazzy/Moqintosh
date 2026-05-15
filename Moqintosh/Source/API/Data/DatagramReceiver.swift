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
    /// Datagrams received for the subscription. Iterate this stream from a single consumer.
    public let datagrams: AsyncStream<ObjectDatagram>
    private let continuation: AsyncStream<ObjectDatagram>.Continuation

    init(sessionContext: SessionContext, subscription: Subscription) {
        self.subscription = subscription
        let streamAndContinuation: (
            stream: AsyncStream<ObjectDatagram>,
            continuation: AsyncStream<ObjectDatagram>.Continuation
        ) = AsyncStream<ObjectDatagram>.makeStream(bufferingPolicy: .bufferingNewest(256))
        self.datagrams = streamAndContinuation.stream
        self.continuation = streamAndContinuation.continuation
        sessionContext.datagramReceiverStore.register(trackAlias: subscription.publishedTrack.trackAlias) { [weak self] datagram in
            self?.yield(datagram)
        }
    }

    deinit {
        continuation.finish()
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
