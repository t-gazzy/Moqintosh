//
//  StreamReceiver.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Receives subgroup objects delivered on a subscription stream.
public protocol StreamReceiverDelegate: AnyObject {
    /// Called when a subgroup object is received.
    func streamReceiver(_ receiver: StreamReceiver, didReceive object: SubgroupObject) async
    /// Called when the receive stream closes.
    func streamReceiverDidClose(_ receiver: StreamReceiver) async
}

// Safe because receiveTask is the only concurrent execution context and delegate callbacks run on that task.
/// Receives subgroup objects for a subscribed track.
public final class StreamReceiver: @unchecked Sendable {

    /// The delegate that receives stream callbacks.
    public weak var delegate: (any StreamReceiverDelegate)?
    /// The subgroup header associated with this receive stream.
    public let header: SubgroupHeader

    private let stream: TransportUniReceiveStream
    private let subscription: Subscription
    private let initialData: Data
    private var receiveTask: Task<Void, Never>?
    var onClose: (@Sendable (StreamReceiver) async -> Void)?

    init(stream: TransportUniReceiveStream, subscription: Subscription, header: SubgroupHeader, initialData: Data) {
        self.stream = stream
        self.subscription = subscription
        self.header = header
        self.initialData = initialData
        self.receiveTask = nil
        self.onClose = nil
    }

    deinit {
        receiveTask?.cancel()
    }

    func start() {
        precondition(receiveTask == nil, "StreamReceiver.start() must only be called once")
        receiveTask = Task { [stream, header, initialData] in
            let frameReader: SubgroupObjectFrameReader = SubgroupObjectFrameReader(header: header, initialData: initialData)
            do {
                while !Task.isCancelled {
                    let object: SubgroupObject = try await frameReader.read(from: stream)
                    await self.delegate?.streamReceiver(self, didReceive: object)
                }
            } catch is CancellationError {
            } catch {
                OSLogger.debug("Stream receive loop ended: \(error)")
            }
            await self.onClose?(self)
            await self.delegate?.streamReceiverDidClose(self)
        }
    }

    func stop() {
        receiveTask?.cancel()
        receiveTask = nil
    }
}

public extension StreamReceiverDelegate {
    func streamReceiverDidClose(_ receiver: StreamReceiver) async {}
}
