//
//  StreamReceiverStore.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

final class StreamReceiverStore {

    typealias Handler = (TransportUniReceiveStream, SubgroupHeader, Data) -> Void

    private let stateQueue: DispatchQueue
    private var handlers: [UInt64: Handler]

    init() {
        self.stateQueue = DispatchQueue(label: "Moqintosh.StreamReceiverStore")
        self.handlers = [:]
    }

    func register(trackAlias: UInt64, handler: @escaping Handler) {
        stateQueue.sync {
            handlers[trackAlias] = handler
        }
    }

    func handler(for trackAlias: UInt64) -> Handler? {
        stateQueue.sync {
            handlers[trackAlias]
        }
    }
}
