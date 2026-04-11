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
    private let controlMessageReceiver: ControlMessageReceiver
    private let streamReceiverCoordinator: StreamReceiverCoordinator
    public weak var delegate: (any SessionDelegate)?

    init(sessionContext: SessionContext, controlMessageReceiver: ControlMessageReceiver) {
        self.context = sessionContext
        self.controlMessageReceiver = controlMessageReceiver
        self.streamReceiverCoordinator = .init(sessionContext: sessionContext)
        self.context.session = self
        self.context.connection.delegate = streamReceiverCoordinator
        self.controlMessageReceiver.start()
    }

    // MARK: - Factory

    public func makePublisher() -> Publisher {
        Publisher(sessionContext: context)
    }

    public func makeSubscriber() -> Subscriber {
        Subscriber(sessionContext: context)
    }
}

/// Errors thrown when a namespace subscription is rejected by the remote publisher.
public enum SubscribeNamespaceError: Error {
    case rejected(code: UInt64, reason: String)
}

/// Errors thrown when a subscription request is rejected by the remote publisher.
public enum SubscribeError: Error {
    case rejected(code: UInt64, reason: String)
}

/// Errors thrown when a namespace publish request is rejected by the remote subscriber.
public enum PublishNamespaceError: Error {
    case rejected(code: UInt64, reason: String)
}

/// Errors thrown when a publish request is rejected by the remote subscriber.
public enum PublishError: Error {
    case rejected(code: UInt64, reason: String)
}
