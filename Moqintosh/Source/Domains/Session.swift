//
//  Session.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

/// Represents a MOQT session created from an Endpoint.
/// Use this to create a Publisher or Subscriber.
public final class Session {

    let connection: TransportConnection

    init(connection: TransportConnection) {
        self.connection = connection
    }

    public func makePublisher() -> Publisher {
        Publisher(session: self)
    }

    public func makeSubscriber() -> Subscriber {
        Subscriber(session: self)
    }
}
