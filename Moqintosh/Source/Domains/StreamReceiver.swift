//
//  StreamReceiver.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

public protocol StreamReceiverDelegate: AnyObject {
    func streamReceiver(_ receiver: StreamReceiver, didReceive object: SubgroupObject)
}

public final class StreamReceiver {

    public weak var delegate: (any StreamReceiverDelegate)?
    public let header: SubgroupHeader

    private let stream: TransportUniReceiveStream
    private let subscription: Subscription
    private let frameReader: SubgroupObjectFrameReader

    init(stream: TransportUniReceiveStream, subscription: Subscription, header: SubgroupHeader, initialData: Data) {
        self.stream = stream
        self.subscription = subscription
        self.header = header
        self.frameReader = .init(header: header, initialData: initialData)
    }

    func start() {
        Task {
            do {
                try await receiveLoop()
            } catch {
                OSLogger.error("Stream receive error: \(error)")
            }
        }
    }

    private func receiveLoop() async throws {
        while true {
            let object: SubgroupObject = try await frameReader.read(from: stream)
            delegate?.streamReceiver(self, didReceive: object)
        }
    }
}
