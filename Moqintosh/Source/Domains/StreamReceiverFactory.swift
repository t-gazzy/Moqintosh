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

    private let session: Session

    init(session: Session, subscription: Subscription) {
        self.session = session
        self.subscription = subscription
        session.context.streamReceiverStore.register(trackAlias: subscription.publishedTrack.trackAlias) { [weak self] stream, header, initialData in
            guard let self else { return }
            let receiver: StreamReceiver = .init(
                stream: stream,
                subscription: subscription,
                header: header,
                initialData: initialData
            )
            self.delegate?.streamReceiverFactory(self, didCreate: receiver)
            receiver.start()
        }
    }
}
