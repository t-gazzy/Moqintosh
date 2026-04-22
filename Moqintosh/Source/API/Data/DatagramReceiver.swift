//
//  DatagramReceiver.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

// Safe because datagram delivery is serialized through AsyncStream and receive() is intended for app-owned consumption.
/// Receives object datagrams for a subscribed track.
public final class DatagramReceiver: @unchecked Sendable {

    /// The subscription associated with this receiver.
    public let subscription: Subscription
    private let datagramContinuation: AsyncStream<ObjectDatagram>.Continuation
    private var datagramIterator: AsyncStream<ObjectDatagram>.Iterator

    init(sessionContext: SessionContext, subscription: Subscription) {
        let datagramStream: (
            stream: AsyncStream<ObjectDatagram>,
            continuation: AsyncStream<ObjectDatagram>.Continuation
        ) = DatagramReceiver.makeDatagramStream()
        self.subscription = subscription
        self.datagramContinuation = datagramStream.continuation
        self.datagramIterator = datagramStream.stream.makeAsyncIterator()
        sessionContext.datagramReceiverStore.register(trackAlias: subscription.publishedTrack.trackAlias) { [weak self] datagram in
            guard let self else { return }
            self.yield(datagram)
        }
    }

    deinit {
        datagramContinuation.finish()
    }

    /// Waits for the next datagram, or returns nil when the receiver closes.
    public func receive() async -> ObjectDatagram? {
        await datagramIterator.next()
    }

    private func yield(_ datagram: ObjectDatagram) {
        let result: AsyncStream<ObjectDatagram>.Continuation.YieldResult = datagramContinuation.yield(datagram)
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
