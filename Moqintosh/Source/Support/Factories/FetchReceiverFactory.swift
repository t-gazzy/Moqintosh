//
//  FetchReceiverFactory.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

/// Receives callbacks when new fetch receivers are created.
public protocol FetchReceiverFactoryDelegate: AnyObject {
    /// Called when a new fetch receiver is created for the accepted fetch request.
    func fetchReceiverFactory(_ factory: FetchReceiverFactory, didCreate receiver: FetchReceiver)
}

/// Creates fetch receivers for inbound fetch streams.
public final class FetchReceiverFactory {

    /// The delegate that receives receiver creation callbacks.
    public weak var delegate: (any FetchReceiverFactoryDelegate)?
    /// The fetch subscription associated with receivers created by this factory.
    public let fetchSubscription: FetchSubscription

    private let delegateQueue: DispatchQueue

    init(sessionContext: SessionContext, fetchSubscription: FetchSubscription) {
        self.fetchSubscription = fetchSubscription
        self.delegateQueue = DispatchQueue(label: "Moqintosh.FetchReceiverFactoryDelegate")
        sessionContext.fetchReceiverStore.register(requestID: fetchSubscription.requestID) { [weak self] stream, _, initialData in
            guard let self else { return }
            let receiver: FetchReceiver = FetchReceiver(
                stream: stream,
                fetchSubscription: fetchSubscription,
                initialData: initialData
            )
            self.delegateQueue.sync {
                self.delegate?.fetchReceiverFactory(self, didCreate: receiver)
            }
            receiver.start()
        }
    }
}
