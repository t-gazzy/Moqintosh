//
//  DatagramReceiverStore.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Synchronization

final class DatagramReceiverStore: Sendable {

    typealias Handler = @Sendable (ObjectDatagram) -> Void

    private let handlers: Mutex<[UInt64: Handler]>

    init() {
        self.handlers = Mutex<[UInt64: Handler]>([:])
    }

    func register(trackAlias: UInt64, handler: @escaping Handler) {
        handlers.withLock { handlers in
            handlers[trackAlias] = handler
        }
    }

    func handler(for trackAlias: UInt64) -> Handler? {
        handlers.withLock { handlers in
            handlers[trackAlias]
        }
    }
}
