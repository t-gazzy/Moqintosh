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

public final class StreamReceiver: @unchecked Sendable {

    public weak var delegate: (any StreamReceiverDelegate)?
    public let header: SubgroupHeader

    private let stream: TransportUniReceiveStream
    private let subscription: Subscription
    private let frameReader: SubgroupObjectFrameReader
    private let delegateQueue: DispatchQueue

    init(stream: TransportUniReceiveStream, subscription: Subscription, header: SubgroupHeader, initialData: Data) {
        self.stream = stream
        self.subscription = subscription
        self.header = header
        self.frameReader = SubgroupObjectFrameReader(header: header, initialData: initialData)
        self.delegateQueue = DispatchQueue(label: "Moqintosh.StreamReceiverDelegate")
    }

    func start() {
        Task {
            do {
                try await receiveLoop()
            } catch {
                OSLogger.debug("Stream receive loop ended: \(error)")
            }
            delegateQueue.async { [weak self] in
                guard let self else { return }
                self.delegate?.streamReceiverDidClose(self)
            }
        }
    }

    private func receiveLoop() async throws {
        while true {
            let object: SubgroupObject = try await frameReader.read(from: stream)
            delegateQueue.async { [weak self] in
                guard let self else { return }
                self.delegate?.streamReceiver(self, didReceive: object)
            }
        }
    }
}

public extension StreamReceiverDelegate {
    func streamReceiverDidClose(_ receiver: StreamReceiver) {}
}
