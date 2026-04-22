//
//  DatagramReceiver.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Receives object datagrams for a subscribed track.
public final class DatagramReceiver {

    /// The datagrams received for this subscription.
    public let datagrams: AsyncStream<ObjectDatagram>
    /// The subscription associated with this receiver.
    public let subscription: Subscription
    private let datagramContinuation: AsyncStream<ObjectDatagram>.Continuation

    init(sessionContext: SessionContext, subscription: Subscription) {
        let datagramStream: (
            stream: AsyncStream<ObjectDatagram>,
            continuation: AsyncStream<ObjectDatagram>.Continuation
        ) = DatagramReceiver.makeDatagramStream()
        self.datagrams = datagramStream.stream
        self.subscription = subscription
        self.datagramContinuation = datagramStream.continuation
        sessionContext.datagramReceiverStore.register(trackAlias: subscription.publishedTrack.trackAlias) { [weak self] datagram in
            guard let self else { return }
            self.datagramContinuation.yield(datagram)
        }
    }

    deinit {
        datagramContinuation.finish()
    }

    private static func makeDatagramStream() -> (
        stream: AsyncStream<ObjectDatagram>,
        continuation: AsyncStream<ObjectDatagram>.Continuation
    ) {
        var streamContinuation: AsyncStream<ObjectDatagram>.Continuation?
        let stream: AsyncStream<ObjectDatagram> = AsyncStream<ObjectDatagram>(
            bufferingPolicy: .bufferingNewest(256)
        ) { continuation in
            streamContinuation = continuation
        }
        guard let streamContinuation else {
            preconditionFailure("AsyncStream must create a continuation")
        }
        return (stream, streamContinuation)
    }
}
