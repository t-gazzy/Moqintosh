//
//  FetchReceiverStore.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

actor FetchReceiverStore {

    typealias Handler = @Sendable (TransportUniReceiveStream, FetchHeader, Data) -> Void

    private var handlers: [UInt64: Handler]

    init() {
        self.handlers = [:]
    }

    func register(requestID: UInt64, handler: @escaping Handler) {
        handlers[requestID] = handler
    }

    func handler(for requestID: UInt64) -> Handler? {
        handlers[requestID]
    }
}
