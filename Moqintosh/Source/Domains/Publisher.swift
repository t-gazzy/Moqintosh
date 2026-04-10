//
//  Publisher.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

/// Represents a MOQT publisher created from a Session.
///
/// A publisher is the sending side of a track.
/// Use the methods below to announce tracks and namespaces.
public final class Publisher {

    public let session: Session

    init(session: Session) {
        self.session = session
    }

    // MARK: - Namespace

    /// Announces a namespace to the subscriber (Section 9.23).
    public func publishNamespace(trackNamespace: TrackNamespace) async throws {
        let requestID: UInt64 = session.context.issueRequestID()
        let message: PublishNamespaceMessage = .init(requestID: requestID, trackNamespace: trackNamespace)
        OSLogger.debug("Sending PUBLISH_NAMESPACE (requestID: \(requestID))")
        try await session.context.controlStream.send(bytes: message.encode())
        try await withCheckedThrowingContinuation { continuation in
            session.context.addRequest(requestID, continuation: continuation)
        }
    }

    /// Ends a previously announced namespace (Section 9.26).
    public func publishNamespaceDone() async throws {
        // TODO: encode and send PUBLISH_NAMESPACE_DONE
    }

    // MARK: - Publish

    /// Initiates a publish for a track (Section 9.13).
    public func publish() async throws {
        // TODO: encode and send PUBLISH
    }

    /// Signals the end of a publish (Section 9.12).
    public func publishDone() async throws {
        // TODO: encode and send PUBLISH_DONE
    }
}
