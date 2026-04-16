//
//  StreamReceiverFactory.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Synchronization

/// Receives callbacks when new stream receivers are created.
public protocol StreamReceiverFactoryDelegate: AnyObject {
    /// Called when a new stream receiver is created for the subscription.
    func streamReceiverFactory(_ factory: StreamReceiverFactory, didCreate receiver: StreamReceiver) async
}

/// Creates stream receivers for inbound subgroup streams on a subscription.
public final class StreamReceiverFactory: @unchecked Sendable {

    /// The delegate that receives receiver creation callbacks.
    public weak var delegate: (any StreamReceiverFactoryDelegate)?
    /// The subscription associated with receivers created by this factory.
    public let subscription: Subscription

    private let sessionContext: SessionContext
    private let activeReceivers: Mutex<[ObjectIdentifier: StreamReceiver]>

    init(sessionContext: SessionContext, subscription: Subscription) {
        self.sessionContext = sessionContext
        self.subscription = subscription
        self.activeReceivers = Mutex<[ObjectIdentifier: StreamReceiver]>([:])
        sessionContext.streamReceiverStore.register(trackAlias: subscription.publishedTrack.trackAlias) { [weak self] stream, header, initialData in
            guard let self else { return }
            let receiver: StreamReceiver = StreamReceiver(
                stream: stream,
                subscription: subscription,
                header: header,
                initialData: initialData
            )
            let receiverID: ObjectIdentifier = ObjectIdentifier(receiver)
            receiver.onClose = { [weak self] receiver in
                self?.removeActiveReceiver(receiver)
            }
            self.activeReceivers.withLock { activeReceivers in
                activeReceivers[receiverID] = receiver
            }
            Task { [weak self, receiver] in
                guard let self else { return }
                await self.delegate?.streamReceiverFactory(self, didCreate: receiver)
                receiver.start()
            }
        }
    }

    private func removeActiveReceiver(_ receiver: StreamReceiver) {
        _ = activeReceivers.withLock { activeReceivers in
            activeReceivers.removeValue(forKey: ObjectIdentifier(receiver))
        }
    }
}
