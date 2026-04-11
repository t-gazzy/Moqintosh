//
//  FetchReceiverFactory.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

public protocol FetchReceiverFactoryDelegate: AnyObject {
    func fetchReceiverFactory(_ factory: FetchReceiverFactory, didCreate receiver: FetchReceiver)
}

public final class FetchReceiverFactory {

    public weak var delegate: (any FetchReceiverFactoryDelegate)?
    public let fetchSubscription: FetchSubscription

    private let delegateQueue: DispatchQueue

    init(sessionContext: SessionContext, fetchSubscription: FetchSubscription) {
        self.fetchSubscription = fetchSubscription
        self.delegateQueue = .init(label: "Moqintosh.FetchReceiverFactoryDelegate")
        sessionContext.fetchReceiverStore.register(requestID: fetchSubscription.requestID) { [weak self] stream, _, initialData in
            guard let self else { return }
            let receiver: FetchReceiver = .init(
                stream: stream,
                fetchSubscription: fetchSubscription,
                initialData: initialData
            )
            self.delegateQueue.async { [weak self] in
                guard let self else { return }
                self.delegate?.fetchReceiverFactory(self, didCreate: receiver)
            }
            receiver.start()
        }
    }
}
