//
//  FetchReceiver.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

/// Receives objects emitted by a fetch stream.
public protocol FetchReceiverDelegate: AnyObject {
    /// Called when a fetch object is received.
    func fetchReceiver(_ receiver: FetchReceiver, didReceive object: SubgroupObject)
    /// Called when the fetch stream closes.
    func fetchReceiverDidClose(_ receiver: FetchReceiver)
}

// Safe because receiveTask is the only concurrent execution context and delegate callbacks are serialized on delegateQueue.
/// Receives subgroup objects from an accepted fetch stream.
public final class FetchReceiver: @unchecked Sendable {

    /// The delegate that receives fetch callbacks.
    public weak var delegate: (any FetchReceiverDelegate)?
    /// The accepted fetch subscription associated with this receiver.
    public let fetchSubscription: FetchSubscription

    private let stream: TransportUniReceiveStream
    private let initialData: Data
    private let delegateQueue: DispatchQueue
    private var receiveTask: Task<Void, Never>?

    init(stream: TransportUniReceiveStream, fetchSubscription: FetchSubscription, initialData: Data) {
        self.stream = stream
        self.fetchSubscription = fetchSubscription
        self.initialData = initialData
        self.delegateQueue = DispatchQueue(label: "Moqintosh.FetchReceiverDelegate")
        self.receiveTask = nil
    }

    deinit {
        receiveTask?.cancel()
    }

    func start() {
        precondition(receiveTask == nil, "FetchReceiver.start() must only be called once")
        receiveTask = Task { [stream, initialData, delegateQueue] in
            let frameReader: FetchObjectFrameReader = FetchObjectFrameReader(initialData: initialData)
            do {
                while !Task.isCancelled {
                    let object: SubgroupObject = try await frameReader.read(from: stream)
                    delegateQueue.sync { [weak self] in
                        guard let self else { return }
                        self.delegate?.fetchReceiver(self, didReceive: object)
                    }
                }
            } catch is CancellationError {
            } catch {
                OSLogger.debug("Fetch receive loop ended: \(error)")
            }
            delegateQueue.sync { [weak self] in
                guard let self else { return }
                self.delegate?.fetchReceiverDidClose(self)
            }
        }
    }

    func stop() {
        receiveTask?.cancel()
        receiveTask = nil
    }
}

public extension FetchReceiverDelegate {
    func fetchReceiverDidClose(_ receiver: FetchReceiver) {}
}
