//
//  SessionContext.swift
//  Moqintosh
//
//  Created by Takemasa Kaji on 2026/04/10.
//

import Foundation

final class SessionContext {

    weak var session: Session?

    let connection: TransportConnection
    let controlStream: TransportBiStream
    let requestStore: SessionRequestStore
    let streamReceiverStore: StreamReceiverStore
    /// Client-side Request IDs start at 0 and increment by 2 (even numbers, Section 9.1).
    private var nextRequestID: UInt64 = 0
    private var nextTrackAlias: UInt64 = 0
    private let stateQueue: DispatchQueue

    init(connection: TransportConnection, controlStream: TransportBiStream) {
        self.connection = connection
        self.controlStream = controlStream
        self.requestStore = SessionRequestStore()
        self.streamReceiverStore = StreamReceiverStore()
        self.stateQueue = DispatchQueue(label: "Moqintosh.SessionContext")
    }

    // MARK: - Request ID

    /// Issues the next Request ID and advances the counter.
    func issueRequestID() -> UInt64 {
        stateQueue.sync {
            let id: UInt64 = nextRequestID
            nextRequestID += 2
            return id
        }
    }

    func issueTrackAlias() -> UInt64 {
        stateQueue.sync {
            let alias: UInt64 = nextTrackAlias
            nextTrackAlias += 1
            return alias
        }
    }
}
