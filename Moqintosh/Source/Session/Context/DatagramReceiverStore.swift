//
//  DatagramReceiverStore.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

final class DatagramReceiverStore {

    typealias Handler = (ObjectDatagram) -> Void

    private let stateQueue: DispatchQueue
    private var handlers: [UInt64: Handler]

    init() {
        self.stateQueue = DispatchQueue(label: "Moqintosh.DatagramReceiverStore")
        self.handlers = [:]
    }

    func register(trackAlias: UInt64, handler: @escaping (ObjectDatagram) -> Void) {
        stateQueue.sync {
            handlers[trackAlias] = handler
        }
    }

    func handler(for trackAlias: UInt64) -> ((ObjectDatagram) -> Void)? {
        stateQueue.sync {
            handlers[trackAlias]
        }
    }
}
