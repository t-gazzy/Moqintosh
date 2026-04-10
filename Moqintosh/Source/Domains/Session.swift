//
//  Session.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

/// Represents a MOQT session created from an Endpoint.
/// Use this to create a Publisher or Subscriber.
public final class Session {

    let context: SessionContext
    public weak var delegate: (any SessionDelegate)?

    init(sessionContext: SessionContext) {
        self.context = sessionContext
        self.context.session = self
    }

    // MARK: - Factory

    public func makePublisher() -> Publisher {
        Publisher(session: self)
    }

    public func makeSubscriber() -> Subscriber {
        Subscriber(session: self)
    }
}

/// Errors thrown when a namespace subscription is rejected by the remote publisher.
public enum SubscribeNamespaceError: Error {
    case rejected(code: UInt64, reason: String)
}

/// Errors thrown when a namespace publish request is rejected by the remote subscriber.
public enum PublishNamespaceError: Error {
    case rejected(code: UInt64, reason: String)
}
