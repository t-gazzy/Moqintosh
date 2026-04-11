//
//  DatagramReceiver.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

public protocol DatagramReceiverDelegate: AnyObject {
    func datagramReceiver(_ receiver: DatagramReceiver, didReceive datagram: ObjectDatagram)
}

public final class DatagramReceiver {

    public weak var delegate: (any DatagramReceiverDelegate)?
    public let subscription: Subscription
    private let delegateQueue: DispatchQueue

    init(sessionContext: SessionContext, subscription: Subscription) {
        self.subscription = subscription
        self.delegateQueue = DispatchQueue(label: "Moqintosh.DatagramReceiverDelegate")
        sessionContext.datagramReceiverStore.register(trackAlias: subscription.publishedTrack.trackAlias) { [weak self] datagram in
            guard let self else { return }
            self.delegateQueue.async { [weak self] in
                guard let self else { return }
                self.delegate?.datagramReceiver(self, didReceive: datagram)
            }
        }
    }
}
