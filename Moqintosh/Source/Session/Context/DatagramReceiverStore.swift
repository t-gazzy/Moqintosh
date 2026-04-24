//
//  DatagramReceiverStore.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

actor DatagramReceiverStore {

    typealias Handler = @Sendable (ObjectDatagram) -> Void

    private var handlers: [UInt64: Handler]

    init() {
        self.handlers = [:]
    }

    func register(trackAlias: UInt64, handler: @escaping Handler) {
        handlers[trackAlias] = handler
    }

    func handler(for trackAlias: UInt64) -> Handler? {
        handlers[trackAlias]
    }
}
