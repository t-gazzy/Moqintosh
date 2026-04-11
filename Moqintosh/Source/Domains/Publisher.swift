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

    private let controlMessageChannel: any ControlMessageChannel
    private let sessionContext: SessionContext

    init(sessionContext: SessionContext) {
        self.controlMessageChannel = sessionContext
        self.sessionContext = sessionContext
    }

    // MARK: - Namespace

    /// Announces a namespace to the subscriber (Section 9.23).
    public func publishNamespace(trackNamespace: TrackNamespace) async throws {
        let requestID: UInt64 = controlMessageChannel.issueRequestID()
        let message: PublishNamespaceMessage = .init(requestID: requestID, trackNamespace: trackNamespace)
        OSLogger.debug("Sending PUBLISH_NAMESPACE (requestID: \(requestID))")
        try await controlMessageChannel.performPublishNamespaceRequest(requestID: requestID, bytes: message.encode())
    }

    /// Ends a previously announced namespace (Section 9.26).
    public func publishNamespaceDone() async throws {
        // TODO: encode and send PUBLISH_NAMESPACE_DONE
    }

    // MARK: - Publish

    /// Initiates a publish for a track (Section 9.13).
    public func publish(
        resource: TrackResource,
        groupOrder: GroupOrder = .ascending,
        contentExist: ContentExist = .noContent,
        forward: Bool = true
    ) async throws -> PublishedTrack {
        let requestID: UInt64 = controlMessageChannel.issueRequestID()
        let trackAlias: UInt64 = controlMessageChannel.issueTrackAlias()
        let publishedTrack: PublishedTrack = .init(
            requestID: requestID,
            resource: resource,
            trackAlias: trackAlias,
            groupOrder: groupOrder,
            contentExist: contentExist,
            forward: forward
        )
        let message: PublishMessage = .init(
            requestID: requestID,
            publishedTrack: publishedTrack,
            deliveryTimeout: nil,
            maxCacheDuration: nil
        )
        OSLogger.debug("Sending PUBLISH (requestID: \(requestID))")
        return try await controlMessageChannel.performPublishRequest(
            requestID: requestID,
            publishedTrack: publishedTrack,
            bytes: message.encode()
        )
    }

    /// Signals the end of a publish (Section 9.12).
    public func publishDone() async throws {
        // TODO: encode and send PUBLISH_DONE
    }

    public func makeStreamFactory(for publishedTrack: PublishedTrack) -> StreamFactory {
        .init(sessionContext: sessionContext, publishedTrack: publishedTrack)
    }

    public func makeDatagramSender(for publishedTrack: PublishedTrack) -> DatagramSender {
        .init(sessionContext: sessionContext, publishedTrack: publishedTrack)
    }
}
