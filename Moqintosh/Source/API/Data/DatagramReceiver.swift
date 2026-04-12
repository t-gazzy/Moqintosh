//
//  DatagramReceiver.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Receives datagram delivery callbacks for a subscription.
public protocol DatagramReceiverDelegate: AnyObject {
    /// Called when an object datagram is received for the bound subscription.
    func datagramReceiver(_ receiver: DatagramReceiver, didReceive datagram: ObjectDatagram)
}

/// Receives object datagrams for a subscribed track.
public final class DatagramReceiver {

    /// The delegate that receives datagram callbacks.
    public weak var delegate: (any DatagramReceiverDelegate)?
    /// The subscription associated with this receiver.
    public let subscription: Subscription
    private let delegateQueue: DispatchQueue

    init(sessionContext: SessionContext, subscription: Subscription) {
        self.subscription = subscription
        self.delegateQueue = DispatchQueue(label: "Moqintosh.DatagramReceiverDelegate")
        sessionContext.datagramReceiverStore.register(trackAlias: subscription.publishedTrack.trackAlias) { [weak self] datagram in
            guard let self else { return }
            self.delegateQueue.sync { [weak self] in
                guard let self else { return }
                self.delegate?.datagramReceiver(self, didReceive: datagram)
            }
        }
    }
}
