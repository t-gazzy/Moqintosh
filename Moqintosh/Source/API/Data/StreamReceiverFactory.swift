//
//  StreamReceiverFactory.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

public protocol StreamReceiverFactoryDelegate: AnyObject {
    func streamReceiverFactory(_ factory: StreamReceiverFactory, didCreate receiver: StreamReceiver)
}

public final class StreamReceiverFactory {

    public weak var delegate: (any StreamReceiverFactoryDelegate)?
    public let subscription: Subscription

    private let sessionContext: SessionContext
    private let delegateQueue: DispatchQueue

    init(sessionContext: SessionContext, subscription: Subscription) {
        self.sessionContext = sessionContext
        self.subscription = subscription
        self.delegateQueue = .init(label: "Moqintosh.StreamReceiverFactoryDelegate")
        sessionContext.streamReceiverStore.register(trackAlias: subscription.publishedTrack.trackAlias) { [weak self] stream, header, initialData in
            guard let self else { return }
            let receiver: StreamReceiver = .init(
                stream: stream,
                subscription: subscription,
                header: header,
                initialData: initialData
            )
            self.delegateQueue.async { [weak self] in
                guard let self else { return }
                self.delegate?.streamReceiverFactory(self, didCreate: receiver)
            }
            receiver.start()
        }
    }
}
