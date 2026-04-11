//
//  DatagramReceiver.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

public protocol DatagramReceiverDelegate: AnyObject {
    func datagramReceiver(_ receiver: DatagramReceiver, didReceive datagram: ObjectDatagram)
}

public final class DatagramReceiver {

    public weak var delegate: (any DatagramReceiverDelegate)?
    public let subscription: Subscription

    init(sessionContext: SessionContext, subscription: Subscription) {
        self.subscription = subscription
        sessionContext.datagramReceiverStore.register(trackAlias: subscription.publishedTrack.trackAlias) { [weak self] datagram in
            guard let self else { return }
            self.delegate?.datagramReceiver(self, didReceive: datagram)
        }
    }
}
