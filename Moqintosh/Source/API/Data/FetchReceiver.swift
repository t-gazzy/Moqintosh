//
//  FetchReceiver.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

public protocol FetchReceiverDelegate: AnyObject {
    func fetchReceiver(_ receiver: FetchReceiver, didReceive object: SubgroupObject)
    func fetchReceiverDidClose(_ receiver: FetchReceiver)
}

public final class FetchReceiver: @unchecked Sendable {

    public weak var delegate: (any FetchReceiverDelegate)?
    public let fetchSubscription: FetchSubscription

    private let stream: TransportUniReceiveStream
    private let frameReader: FetchObjectFrameReader
    private let delegateQueue: DispatchQueue

    init(stream: TransportUniReceiveStream, fetchSubscription: FetchSubscription, initialData: Data) {
        self.stream = stream
        self.fetchSubscription = fetchSubscription
        self.frameReader = FetchObjectFrameReader(initialData: initialData)
        self.delegateQueue = DispatchQueue(label: "Moqintosh.FetchReceiverDelegate")
    }

    func start() {
        Task {
            do {
                try await receiveLoop()
            } catch {
                OSLogger.debug("Fetch receive loop ended: \(error)")
            }
            delegateQueue.async { [weak self] in
                guard let self else { return }
                self.delegate?.fetchReceiverDidClose(self)
            }
        }
    }

    private func receiveLoop() async throws {
        while true {
            let object: SubgroupObject = try await frameReader.read(from: stream)
            delegateQueue.async { [weak self] in
                guard let self else { return }
                self.delegate?.fetchReceiver(self, didReceive: object)
            }
        }
    }
}

public extension FetchReceiverDelegate {
    func fetchReceiverDidClose(_ receiver: FetchReceiver) {}
}
