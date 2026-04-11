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
        let requestID: UInt64 = try await controlMessageChannel.issueRequestID()
        let message: PublishNamespaceMessage = PublishNamespaceMessage(requestID: requestID, trackNamespace: trackNamespace)
        OSLogger.debug("Sending PUBLISH_NAMESPACE (requestID: \(requestID))")
        try await controlMessageChannel.performPublishNamespaceRequest(requestID: requestID, bytes: message.encode())
    }

    /// Ends a previously announced namespace (Section 9.26).
    public func publishNamespaceDone(trackNamespace: TrackNamespace) async throws {
        let message: PublishNamespaceDoneMessage = PublishNamespaceDoneMessage(trackNamespace: trackNamespace)
        OSLogger.debug("Sending PUBLISH_NAMESPACE_DONE")
        try await controlMessageChannel.sendControlMessage(bytes: message.encode())
    }

    // MARK: - Publish

    /// Initiates a publish for a track (Section 9.13).
    public func publish(
        resource: TrackResource,
        groupOrder: GroupOrder = .ascending,
        contentExist: ContentExist = .noContent,
        forward: Bool = true
    ) async throws -> PublishedTrack {
        let requestID: UInt64 = try await controlMessageChannel.issueRequestID()
        let trackAlias: UInt64 = controlMessageChannel.issueTrackAlias()
        let publishedTrack: PublishedTrack = PublishedTrack(
            requestID: requestID,
            resource: resource,
            trackAlias: trackAlias,
            groupOrder: groupOrder,
            contentExist: contentExist,
            forward: forward
        )
        let message: PublishMessage = PublishMessage(
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
    public func publishDone(
        for publishedTrack: PublishedTrack,
        statusCode: UInt64,
        streamCount: UInt64,
        reasonPhrase: String = ""
    ) async throws {
        let message: PublishDoneMessage = PublishDoneMessage(
            requestID: publishedTrack.requestID,
            statusCode: statusCode,
            streamCount: streamCount,
            reasonPhrase: reasonPhrase
        )
        OSLogger.debug("Sending PUBLISH_DONE (requestID: \(publishedTrack.requestID))")
        try await controlMessageChannel.sendControlMessage(bytes: message.encode())
    }

    public func makeStreamSenderFactory(for publishedTrack: PublishedTrack) -> StreamSenderFactory {
        StreamSenderFactory(sessionContext: sessionContext, publishedTrack: publishedTrack)
    }

    public func makeDatagramSender(for publishedTrack: PublishedTrack) -> DatagramSender {
        DatagramSender(sessionContext: sessionContext, publishedTrack: publishedTrack)
    }

    public func makeFetchSender(for fetchRequest: FetchRequest) async throws -> FetchSender {
        let stream: TransportUniSendStream = try await sessionContext.connection.openUniStream()
        return try await FetchSender(stream: stream, requestID: fetchRequest.requestID)
    }
}
