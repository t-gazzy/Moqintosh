//
//  StreamReceiverFactory.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Receives callbacks when new stream receivers are created.
public protocol StreamReceiverFactoryDelegate: AnyObject {
    /// Called when a new stream receiver is created for the subscription.
    func streamReceiverFactory(_ factory: StreamReceiverFactory, didCreate receiver: StreamReceiver)
}

/// Creates stream receivers for inbound subgroup streams on a subscription.
public final class StreamReceiverFactory {

    /// The delegate that receives receiver creation callbacks.
    public weak var delegate: (any StreamReceiverFactoryDelegate)?
    /// The subscription associated with receivers created by this factory.
    public let subscription: Subscription

    private let sessionContext: SessionContext
    private let delegateQueue: DispatchQueue

    init(sessionContext: SessionContext, subscription: Subscription) {
        self.sessionContext = sessionContext
        self.subscription = subscription
        self.delegateQueue = DispatchQueue(label: "Moqintosh.StreamReceiverFactoryDelegate")
        sessionContext.streamReceiverStore.register(trackAlias: subscription.publishedTrack.trackAlias) { [weak self] stream, header, initialData in
            guard let self else { return }
            let receiver: StreamReceiver = StreamReceiver(
                stream: stream,
                subscription: subscription,
                header: header,
                initialData: initialData
            )
            self.delegateQueue.sync {
                self.delegate?.streamReceiverFactory(self, didCreate: receiver)
            }
            receiver.start()
        }
    }
}
