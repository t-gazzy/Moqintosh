//
//  FetchReceiverStore.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

final class FetchReceiverStore {

    typealias Handler = @Sendable (TransportUniReceiveStream, FetchHeader, Data) -> Void

    private let stateQueue: DispatchQueue
    private var handlers: [UInt64: Handler]

    init() {
        self.stateQueue = DispatchQueue(label: "Moqintosh.FetchReceiverStore")
        self.handlers = [:]
    }

    func register(requestID: UInt64, handler: @escaping Handler) {
        stateQueue.sync {
            handlers[requestID] = handler
        }
    }

    func handler(for requestID: UInt64) -> Handler? {
        stateQueue.sync {
            handlers[requestID]
        }
    }
}
