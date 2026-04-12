//
//  StreamReceiver.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

public protocol StreamReceiverDelegate: AnyObject {
    func streamReceiver(_ receiver: StreamReceiver, didReceive object: SubgroupObject)
    func streamReceiverDidClose(_ receiver: StreamReceiver)
}

// Safe because receiveTask is the only concurrent execution context and delegate callbacks are serialized on delegateQueue.
public final class StreamReceiver: @unchecked Sendable {

    public weak var delegate: (any StreamReceiverDelegate)?
    public let header: SubgroupHeader

    private let stream: TransportUniReceiveStream
    private let subscription: Subscription
    private let initialData: Data
    private let delegateQueue: DispatchQueue
    private var receiveTask: Task<Void, Never>?

    init(stream: TransportUniReceiveStream, subscription: Subscription, header: SubgroupHeader, initialData: Data) {
        self.stream = stream
        self.subscription = subscription
        self.header = header
        self.initialData = initialData
        self.delegateQueue = DispatchQueue(label: "Moqintosh.StreamReceiverDelegate")
        self.receiveTask = nil
    }

    deinit {
        receiveTask?.cancel()
    }

    func start() {
        precondition(receiveTask == nil, "StreamReceiver.start() must only be called once")
        receiveTask = Task { [stream, header, initialData, delegateQueue] in
            let frameReader: SubgroupObjectFrameReader = SubgroupObjectFrameReader(header: header, initialData: initialData)
            do {
                while !Task.isCancelled {
                    let object: SubgroupObject = try await frameReader.read(from: stream)
                    delegateQueue.sync { [weak self] in
                        guard let self else { return }
                        self.delegate?.streamReceiver(self, didReceive: object)
                    }
                }
            } catch is CancellationError {
            } catch {
                OSLogger.debug("Stream receive loop ended: \(error)")
            }
            delegateQueue.sync { [weak self] in
                guard let self else { return }
                self.delegate?.streamReceiverDidClose(self)
            }
        }
    }

    func stop() {
        receiveTask?.cancel()
        receiveTask = nil
    }
}

public extension StreamReceiverDelegate {
    func streamReceiverDidClose(_ receiver: StreamReceiver) {}
}
