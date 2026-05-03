//
//  CallApplicationCoordinator.swift
//  CallApplicationSample
//
//  Created by Codex on 2026/04/22.
//

import Foundation
import Moqintosh

#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
import RealtimeMediaKit
#endif

@MainActor
final class CallApplicationCoordinator: NSObject, CallApplicationCoordinating {
    private struct PublishedNamespaceRecord {
        let id: UUID
        let namespace: TrackNamespace

        var presentation: CallApplicationPresentationState.NamespaceItem {
            CallApplicationPresentationState.NamespaceItem(
                id: id,
                displayName: namespace.joinedUTF8Elements()
            )
        }
    }

    private struct SubscribedNamespaceRecord {
        let id: UUID
        let namespace: TrackNamespace

        var presentation: CallApplicationPresentationState.NamespaceItem {
            CallApplicationPresentationState.NamespaceItem(
                id: id,
                displayName: namespace.joinedUTF8Elements()
            )
        }
    }

    private struct PublishedTrackRecord {
        let namespaceID: UUID
        let publishedTrack: PublishedTrack
        let kind: CallApplicationPresentationState.TrackKind

        var presentation: CallApplicationPresentationState.PublishedTrackItem {
            CallApplicationPresentationState.PublishedTrackItem(
                id: publishedTrack.requestID,
                namespaceID: namespaceID,
                displayName: "\(publishedTrack.resource.trackNamespace.joinedUTF8Elements())/\(kind.rawValue)",
                forwardDescription: publishedTrack.forward ? "1" : "0",
                kind: kind
            )
        }
    }

    private struct InboundSubscriptionRecord {
        let publishedTrack: PublishedTrack
        let kind: CallApplicationPresentationState.TrackKind
        let matchingPublishedTrackID: UInt64
        var selectedMode: CallApplicationPresentationState.DeliveryMode?

        var presentation: CallApplicationPresentationState.InboundSubscriptionItem {
            CallApplicationPresentationState.InboundSubscriptionItem(
                id: publishedTrack.requestID,
                displayName: "\(publishedTrack.resource.trackNamespace.joinedUTF8Elements())/\(kind.rawValue)",
                forwardDescription: publishedTrack.forward ? "1" : "0",
                kind: kind,
                matchingPublishedTrackID: matchingPublishedTrackID,
                canStartDelivery: true,
                selectedMode: selectedMode
            )
        }
    }

    private struct RemoteTrackRecord {
        let subscription: Moqintosh.Subscription
        let kind: CallApplicationPresentationState.TrackKind

        var presentation: CallApplicationPresentationState.RemoteTrackItem {
            CallApplicationPresentationState.RemoteTrackItem(
                id: subscription.requestID,
                displayName: "\(subscription.publishedTrack.resource.trackNamespace.joinedUTF8Elements())/\(kind.rawValue)",
                kind: kind
            )
        }
    }

    private struct ActiveFetchRecord {
        let fetchSubscription: FetchSubscription
        let kind: CallApplicationPresentationState.TrackKind

        var presentation: CallApplicationPresentationState.ActiveFetchItem {
            CallApplicationPresentationState.ActiveFetchItem(
                id: fetchSubscription.requestID,
                displayName: "\(fetchSubscription.resource.trackNamespace.joinedUTF8Elements())/\(kind.rawValue)",
                kind: kind
            )
        }
    }

    weak var delegate: (any CallApplicationCoordinatorDelegate)?

    private let audioFormat: AudioFormat
    private let videoFormat: VideoFormat
    private let iso8601Formatter: ISO8601DateFormatter
    private lazy var mediaController: CallApplicationMediaController = CallApplicationMediaController(
        audioFormat: audioFormat,
        videoFormat: videoFormat,
        onEvent: { [weak self] message in
            self?.appendEvent(message)
        },
        onDataPacket: { [weak self] resource, packet in
            self?.appendDataLog(resource: resource, packet: packet)
        }
    )

    private var state: CallApplicationPresentationState
    private weak var session: Session?
    private var publisher: Moqintosh.Publisher?
    private var subscriber: Moqintosh.Subscriber?

    private var publishedNamespaceRecords: [PublishedNamespaceRecord]
    private var subscribedNamespaceRecords: [SubscribedNamespaceRecord]
    private var publishedTrackRecords: [PublishedTrackRecord]
    private var inboundSubscriptionRecords: [InboundSubscriptionRecord]
    private var remoteTrackRecords: [RemoteTrackRecord]
    private var activeFetchRecords: [ActiveFetchRecord]

    override init() {
        self.audioFormat = AudioFormat(
            sampleRate: 48_000,
            channelCount: 1,
            bytesPerSample: MemoryLayout<Float>.size
        )
        self.videoFormat = VideoFormat(width: 640, height: 480, framesPerSecond: 30)
        self.iso8601Formatter = ISO8601DateFormatter()
        self.state = CallApplicationPresentationState()
        self.publishedNamespaceRecords = []
        self.subscribedNamespaceRecords = []
        self.publishedTrackRecords = []
        self.inboundSubscriptionRecords = []
        self.remoteTrackRecords = []
        self.activeFetchRecords = []
        super.init()
    }

    func connect(endpointAddress: String, allowsUntrustedCertificates: Bool) async {
        guard !state.isConnecting else {
            return
        }

        updateState { state in
            state.isConnecting = true
            state.connectionErrorMessage = nil
        }

        do {
            let endpointParts: (host: String, port: UInt16) = try parseEndpoint(address: endpointAddress)
            let endpoint: Endpoint = Endpoint(host: endpointParts.host, port: endpointParts.port)
            let connectedSession: Session = try await endpoint.connect(
                allowsUntrustedCertificates: allowsUntrustedCertificates
            )
            connectedSession.delegate = self
            self.session = connectedSession
            self.publisher = connectedSession.makePublisher()
            self.subscriber = connectedSession.makeSubscriber()
            updateState { state in
                state.isConnecting = false
                state.isConnected = true
                state.connectedEndpointDescription = "\(endpointParts.host):\(endpointParts.port)"
            }
            appendEvent("Connected to \(state.connectedEndpointDescription)")
        } catch {
            updateState { state in
                state.isConnecting = false
                state.connectionErrorMessage = String(describing: error)
            }
            appendEvent("Connection failed: \(error)")
        }
    }

    func publishNamespace(input: String) async {
        guard let publisher else {
            appendEvent("Session is not connected.")
            return
        }
        guard let trackNamespace: TrackNamespace = parseNamespace(from: input) else {
            appendEvent("Invalid publish namespace.")
            return
        }

        do {
            try await publisher.publishNamespace(trackNamespace: trackNamespace)
            let record: PublishedNamespaceRecord = PublishedNamespaceRecord(id: UUID(), namespace: trackNamespace)
            publishedNamespaceRecords.append(record)
            syncPresentationCollections()
            appendEvent("Published namespace \(record.presentation.displayName)")
        } catch {
            appendEvent("Failed to publish namespace: \(error)")
        }
    }

    func subscribeNamespace(input: String) async {
        guard let subscriber else {
            appendEvent("Session is not connected.")
            return
        }
        guard let namespacePrefix: TrackNamespace = parseNamespace(from: input) else {
            appendEvent("Invalid subscribe namespace.")
            return
        }

        do {
            try await subscriber.subscribeNamespace(namespacePrefix: namespacePrefix)
            let record: SubscribedNamespaceRecord = SubscribedNamespaceRecord(id: UUID(), namespace: namespacePrefix)
            subscribedNamespaceRecords.append(record)
            syncPresentationCollections()
            appendEvent("Subscribed namespace \(record.presentation.displayName)")
        } catch {
            appendEvent("Failed to subscribe namespace: \(error)")
        }
    }

    func publishTrack(
        selectedNamespaceID: UUID?,
        trackKind: CallApplicationPresentationState.TrackKind,
        forward: Bool
    ) async {
        guard let publisher else {
            appendEvent("Session is not connected.")
            return
        }
        guard let selectedNamespaceID else {
            appendEvent("Select a namespace first.")
            return
        }
        guard let namespaceRecord: PublishedNamespaceRecord = publishedNamespaceRecords.first(where: { $0.id == selectedNamespaceID }) else {
            appendEvent("Selected namespace is missing.")
            return
        }

        let resource: TrackResource = TrackResource(
            trackNamespace: namespaceRecord.namespace,
            trackName: Data(trackKind.rawValue.utf8)
        )

        do {
            let publishedTrack: PublishedTrack = try await publisher.publish(
                resource: resource,
                groupOrder: GroupOrder.ascending,
                contentExist: ContentExist.noContent,
                forward: forward
            )
            let record: PublishedTrackRecord = PublishedTrackRecord(
                namespaceID: namespaceRecord.id,
                publishedTrack: publishedTrack,
                kind: trackKind
            )
            publishedTrackRecords.append(record)
            syncPresentationCollections()
            appendEvent("Published track \(record.presentation.displayName)")
        } catch {
            appendEvent("Failed to publish track: \(error)")
        }
    }

    func startSending(
        requestID: UInt64,
        mode: CallApplicationPresentationState.DeliveryMode
    ) async {
        guard let publisher else {
            appendEvent("Publisher is unavailable.")
            return
        }
        guard let requestIndex: Int = inboundSubscriptionRecords.firstIndex(where: { $0.publishedTrack.requestID == requestID }) else {
            appendEvent("Subscribe request \(requestID) is missing.")
            return
        }

        let record: InboundSubscriptionRecord = inboundSubscriptionRecords[requestIndex]
        if !record.publishedTrack.forward {
            appendEvent("forward=0 for \(record.presentation.displayName). Media will not be sent.")
            inboundSubscriptionRecords[requestIndex].selectedMode = mode
            syncPresentationCollections()
            return
        }

        await mediaController.stopSendSessions(for: record.kind)

        do {
            let resourceKey: String = self.resourceKey(for: record.publishedTrack.resource)
            let packetSender: any RealtimeMediaPacketSender = try await mediaController.makePacketSender(
                for: record.publishedTrack,
                mode: mode,
                resourceKey: resourceKey,
                publisher: publisher
            )
            try await mediaController.startSending(
                requestID: requestID,
                kind: record.kind,
                packetSender: packetSender
            )
            inboundSubscriptionRecords[requestIndex].selectedMode = mode
            syncPresentationCollections()
            appendEvent("Started \(mode.rawValue) delivery for \(record.presentation.displayName)")
        } catch {
            appendEvent("Failed to start \(mode.rawValue) delivery: \(error)")
        }
    }

    func publishDone(requestID: UInt64) async {
        guard let publisher else {
            return
        }
        guard let trackRecord: PublishedTrackRecord = publishedTrackRecords.first(where: { $0.publishedTrack.requestID == requestID }) else {
            return
        }

        do {
            try await publisher.publishDone(
                for: trackRecord.publishedTrack,
                statusCode: 0,
                streamCount: 1,
                reasonPhrase: "Completed by sample"
            )
            appendEvent("Sent publish_done for \(trackRecord.presentation.displayName)")
        } catch {
            appendEvent("Failed to send publish_done: \(error)")
        }
    }

    func publishNamespaceDone(namespaceID: UUID) async {
        guard let publisher else {
            return
        }
        guard let namespaceRecord: PublishedNamespaceRecord = publishedNamespaceRecords.first(where: { $0.id == namespaceID }) else {
            return
        }

        do {
            try await publisher.publishNamespaceDone(trackNamespace: namespaceRecord.namespace)
            appendEvent("Sent publish_namespace_done for \(namespaceRecord.presentation.displayName)")
        } catch {
            appendEvent("Failed to send publish_namespace_done: \(error)")
        }
    }

    func unsubscribeNamespace(namespaceID: UUID) async {
        guard let subscriber else {
            return
        }
        guard let namespaceRecord: SubscribedNamespaceRecord = subscribedNamespaceRecords.first(where: { $0.id == namespaceID }) else {
            return
        }

        do {
            try await subscriber.unsubscribeNamespace(namespacePrefix: namespaceRecord.namespace)
            subscribedNamespaceRecords.removeAll { $0.id == namespaceID }
            syncPresentationCollections()
            appendEvent("Sent unsubscribe_namespace for \(namespaceRecord.presentation.displayName)")
        } catch {
            appendEvent("Failed to send unsubscribe_namespace: \(error)")
        }
    }

    func unsubscribeRemoteTrack(requestID: UInt64) async {
        guard let subscriber else {
            return
        }
        guard let remoteTrackRecord: RemoteTrackRecord = remoteTrackRecords.first(where: { $0.subscription.requestID == requestID }) else {
            return
        }

        do {
            try await subscriber.unsubscribe(for: remoteTrackRecord.subscription)
            finishRemoteTrack(requestID: requestID)
            appendEvent("Sent unsubscribe for \(remoteTrackRecord.presentation.displayName)")
        } catch {
            appendEvent("Failed to send unsubscribe: \(error)")
        }
    }

    func fetchRemoteTrack(
        selectedTrackID: UInt64?,
        startObjectText: String,
        endObjectText: String
    ) async {
        guard let subscriber else {
            return
        }
        guard let selectedTrackID else {
            appendEvent("Select a remote track for fetch.")
            return
        }
        guard let remoteTrackRecord: RemoteTrackRecord = remoteTrackRecords.first(where: { $0.subscription.requestID == selectedTrackID }) else {
            appendEvent("Selected fetch track is missing.")
            return
        }
        guard
            let startObject: UInt64 = UInt64(startObjectText),
            let endObject: UInt64 = UInt64(endObjectText),
            endObject >= startObject
        else {
            appendEvent("Invalid fetch range.")
            return
        }

        do {
            let fetchSubscription: FetchSubscription = try await subscriber.fetch(
                resource: remoteTrackRecord.subscription.publishedTrack.resource,
                start: Location(group: 0, object: startObject),
                end: Location(group: 0, object: endObject)
            )
            let record: ActiveFetchRecord = ActiveFetchRecord(
                fetchSubscription: fetchSubscription,
                kind: remoteTrackRecord.kind
            )
            activeFetchRecords.append(record)
            syncPresentationCollections()
            mediaController.beginFetchReceiving(
                fetchSubscription: fetchSubscription,
                kind: record.kind,
                subscriber: subscriber
            )
            appendEvent("Started fetch for \(record.presentation.displayName)")
        } catch {
            appendEvent("Failed to fetch remote track: \(error)")
        }
    }

    func cancelFetch(requestID: UInt64) async {
        guard let subscriber else {
            return
        }
        guard let record: ActiveFetchRecord = activeFetchRecords.first(where: { $0.fetchSubscription.requestID == requestID }) else {
            return
        }

        do {
            try await subscriber.fetchCancel(for: record.fetchSubscription)
            mediaController.cancelFetchTask(requestID: requestID)
            activeFetchRecords.removeAll { $0.fetchSubscription.requestID == requestID }
            syncPresentationCollections()
            appendEvent("Sent fetch_cancel for \(record.presentation.displayName)")
        } catch {
            appendEvent("Failed to send fetch_cancel: \(error)")
        }
    }

    func sendGoAway() async {
        guard let session else {
            return
        }

        do {
            try await session.goAway()
            appendEvent("Sent goaway")
        } catch {
            appendEvent("Failed to send goaway: \(error)")
        }
    }

    #if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
    func videoRenderView(for remoteTrackID: UInt64?) -> VideoRenderView? {
        mediaController.videoRenderView(for: remoteTrackID)
    }
    #endif
}

extension CallApplicationCoordinator: SessionDelegate {
    func session(
        _ session: Session,
        didReceiveSubscribeNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) async -> SubscribeNamespaceDecision {
        appendEvent("Received subscribe_namespace for \(prefix.joinedUTF8Elements())")
        let matched: Bool = publishedNamespaceRecords.contains { record in
            isNamespace(prefix, matchingPrefixOf: record.namespace)
        }
        if matched {
            return .accept
        }
        return .reject(
            SubscribeNamespaceRequestError(
                code: .namespacePrefixUnknown,
                reason: "Namespace prefix unknown"
            )
        )
    }

    func session(_ session: Session, didReceiveSubscribe publishedTrack: PublishedTrack) async -> SubscribeDecision {
        guard let matchingTrackRecord: PublishedTrackRecord = publishedTrackRecords.first(where: {
            resourceKey(for: $0.publishedTrack.resource) == resourceKey(for: publishedTrack.resource)
        }) else {
            appendEvent("Rejected subscribe for unknown track.")
            return .reject(
                SubscribeRequestError(
                    code: .trackDoesNotExist,
                    reason: "Track does not exist"
                )
            )
        }

        let record: InboundSubscriptionRecord = InboundSubscriptionRecord(
            publishedTrack: publishedTrack,
            kind: trackKind(for: publishedTrack.resource),
            matchingPublishedTrackID: matchingTrackRecord.publishedTrack.requestID,
            selectedMode: nil
        )
        inboundSubscriptionRecords.removeAll { $0.publishedTrack.requestID == record.publishedTrack.requestID }
        inboundSubscriptionRecords.append(record)
        syncPresentationCollections()
        appendEvent("Received subscribe for \(record.presentation.displayName)")
        return .accept(SubscribeAcceptance(publishedTrack: publishedTrack))
    }

    func session(_ session: Session, didReceiveSubscribeUpdate update: SubscribeUpdate) async {
        appendEvent(
            "Received subscribe_update requestID=\(update.requestID) start=\(update.start.group):\(update.start.object) endGroup=\(update.endGroup) forward=\(update.forward)"
        )
        if !update.forward {
            await mediaController.stopSendSession(requestID: update.requestID)
        }
    }

    func session(_ session: Session, didReceiveUnsubscribe requestID: UInt64) async {
        appendEvent("Received unsubscribe for requestID=\(requestID)")
        inboundSubscriptionRecords.removeAll { $0.publishedTrack.requestID == requestID }
        syncPresentationCollections()
        await mediaController.stopSendSession(requestID: requestID)
    }

    func session(_ session: Session, didReceiveFetch request: FetchRequest) async -> FetchDecision {
        let requestResource: TrackResource = resource(from: request)
        let resourceKey: String = self.resourceKey(for: requestResource)
        guard let endLocation: Location = await mediaController.endLocation(for: resourceKey) else {
            appendEvent("Rejected fetch for \(resourceDescription(requestResource)) because no history exists.")
            return .reject(
                FetchRequestError(
                    code: .noObjects,
                    reason: "No cached objects"
                )
            )
        }

        let response: FetchResponse = FetchResponse(
            groupOrder: GroupOrder.ascending,
            endOfTrack: false,
            endLocation: endLocation,
            maxCacheDuration: nil
        )
        appendEvent("Accepted fetch for \(resourceDescription(requestResource))")
        guard let publisher else {
            return .reject(
                FetchRequestError(
                    code: .internalError,
                    reason: "Publisher unavailable"
                )
            )
        }
        Task { [weak self] in
            do {
                try await self?.mediaController.sendFetchResponse(
                    publisher: publisher,
                    request: request,
                    resourceKey: resourceKey
                )
            } catch {
                self?.appendEvent("Failed to send fetch response: \(error)")
            }
        }
        return .accept(response)
    }

    func session(_ session: Session, didReceiveFetchCancel requestID: UInt64) async {
        appendEvent("Received fetch_cancel for requestID=\(requestID)")
        mediaController.cancelFetchTask(requestID: requestID)
    }

    func session(_ session: Session, didReceiveTrackStatus request: TrackStatusRequest) async -> TrackStatusDecision {
        let requestResource: TrackResource = request.resource
        let resourceKey: String = self.resourceKey(for: requestResource)
        guard let endLocation: Location = await mediaController.endLocation(for: resourceKey) else {
            return .reject(
                TrackStatusRequestError(
                    code: .trackDoesNotExist,
                    reason: "Track does not exist"
                )
            )
        }
        let status: TrackStatus = TrackStatus(
            expires: 0,
            groupOrder: GroupOrder.ascending,
            contentExist: ContentExist.exists(endLocation),
            deliveryTimeout: nil,
            maxCacheDuration: nil
        )
        return .accept(status)
    }

    func session(
        _ session: Session,
        didReceivePublishNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) async -> PublishNamespaceDecision {
        appendEvent("Received publish_namespace for \(prefix.joinedUTF8Elements())")
        return .accept
    }

    func session(_ session: Session, didReceivePublish resource: TrackResource) async -> PublishDecision {
        appendEvent("Received publish for \(resourceDescription(resource))")
        Task { [weak self] in
            await self?.subscribeToRemoteTrack(resource: resource)
        }
        return .accept(PublishAcceptance())
    }

    func session(_ session: Session, didReceivePublishDone publishDone: PublishDone) async {
        appendEvent("Received publish_done requestID=\(publishDone.requestID)")
    }

    func session(_ session: Session, didReceivePublishNamespaceDone trackNamespace: TrackNamespace) async {
        appendEvent("Received publish_namespace_done for \(trackNamespace.joinedUTF8Elements())")
    }

    func session(_ session: Session, didReceiveGoAway newSessionURI: String?) async {
        appendEvent("Received goaway")
    }

    func session(_ session: Session, didReceiveUnsubscribeNamespace namespacePrefix: TrackNamespace) async {
        appendEvent("Received unsubscribe_namespace for \(namespacePrefix.joinedUTF8Elements())")
    }

    func session(_ session: Session, didReceivePublishNamespaceCancel cancellation: PublishNamespaceCancel) async {
        appendEvent(
            "Received publish_namespace_cancel for \(cancellation.trackNamespace.joinedUTF8Elements()) reason=\(cancellation.reasonPhrase)"
        )
    }
}

private extension CallApplicationCoordinator {
    func updateState(_ mutate: (inout CallApplicationPresentationState) -> Void) {
        mutate(&state)
        delegate?.coordinator(self, didUpdate: state)
    }

    func syncPresentationCollections() {
        updateState { state in
            state.activePublishedNamespaces = publishedNamespaceRecords.map(\.presentation)
            state.activeSubscribedNamespaces = subscribedNamespaceRecords.map(\.presentation)
            state.localPublishedTracks = publishedTrackRecords.map(\.presentation)
            state.inboundSubscriptionRequests = inboundSubscriptionRecords.map(\.presentation)
            state.remoteTracks = remoteTrackRecords.map(\.presentation)
            state.remoteVideoTracks = remoteTrackRecords
                .filter { $0.kind == .video }
                .map {
                    CallApplicationPresentationState.RemoteVideoItem(
                        id: $0.subscription.requestID,
                        displayName: $0.presentation.displayName
                    )
                }
            state.activeFetchSubscriptions = activeFetchRecords.map(\.presentation)
        }
    }

    func appendEvent(_ message: String) {
        let timestamp: String = iso8601Formatter.string(from: Date())
        updateState { state in
            state.eventLogLines.insert("[\(timestamp)] \(message)", at: 0)
            if state.eventLogLines.count > 200 {
                state.eventLogLines.removeLast(state.eventLogLines.count - 200)
            }
        }
    }

    func appendDataLog(resource: TrackResource, packet: TimedMediaPacket) {
        let payloadString: String = String(data: packet.payload, encoding: .utf8) ?? "<binary>"
        let line: String = "\(resourceDescription(resource)) @ \(payloadString)"
        updateState { state in
            state.dataLogLines.insert(line, at: 0)
            if state.dataLogLines.count > 200 {
                state.dataLogLines.removeLast(state.dataLogLines.count - 200)
            }
        }
    }

    func parseEndpoint(address: String) throws -> (host: String, port: UInt16) {
        let parts: [String] = address.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let port: UInt16 = UInt16(parts[1]) else {
            throw NSError(
                domain: "CallApplicationSample",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Endpoint must be host:port"]
            )
        }
        return (parts[0], port)
    }

    func parseNamespace(from value: String) -> TrackNamespace? {
        let elements: [String] = value
            .split(separator: "/")
            .map { String($0) }
            .filter { !$0.isEmpty }
        guard !elements.isEmpty else {
            return nil
        }
        return TrackNamespace(strings: elements)
    }

    func trackKind(for resource: TrackResource) -> CallApplicationPresentationState.TrackKind {
        let trackName: String = String(data: resource.trackName, encoding: .utf8) ?? CallApplicationPresentationState.TrackKind.data.rawValue
        return CallApplicationPresentationState.TrackKind(rawValue: trackName) ?? .data
    }

    func resourceKey(for resource: TrackResource) -> String {
        "\(resource.trackNamespace.joinedUTF8Elements())::\(String(data: resource.trackName, encoding: .utf8) ?? "binary")"
    }

    func resourceDescription(_ resource: TrackResource) -> String {
        "\(resource.trackNamespace.joinedUTF8Elements())/\(String(data: resource.trackName, encoding: .utf8) ?? "binary")"
    }

    func isNamespace(_ namespace: TrackNamespace, matchingPrefixOf target: TrackNamespace) -> Bool {
        let namespaceElements: [String?] = namespace.utf8Elements
        let targetElements: [String?] = target.utf8Elements
        guard namespaceElements.count <= targetElements.count else {
            return false
        }
        return zip(namespaceElements, targetElements).allSatisfy { pair in
            pair.0 == pair.1
        }
    }

    func subscribeToRemoteTrack(resource: TrackResource) async {
        guard let subscriber else {
            return
        }
        let currentResourceKey: String = resourceKey(for: resource)
        if remoteTrackRecords.contains(where: {
            resourceKey(for: $0.subscription.publishedTrack.resource) == currentResourceKey
        }) {
            return
        }

        do {
            let subscription: Moqintosh.Subscription = try await subscriber.subscribe(resource: resource)
            let record: RemoteTrackRecord = RemoteTrackRecord(
                subscription: subscription,
                kind: trackKind(for: resource)
            )
            remoteTrackRecords.append(record)
            syncPresentationCollections()
            try await mediaController.beginReceiving(
                subscription: subscription,
                kind: record.kind,
                subscriber: subscriber
            )
            appendEvent("Subscribed remote track \(record.presentation.displayName)")
        } catch {
            appendEvent("Failed to subscribe remote track: \(error)")
        }
    }

    func finishRemoteTrack(requestID: UInt64) {
        mediaController.finishRemoteTrack(requestID: requestID)
        remoteTrackRecords.removeAll { $0.subscription.requestID == requestID }
        syncPresentationCollections()
    }

    func resource(from request: FetchRequest) -> TrackResource {
        switch request {
        case .standalone(_, let resource, _, _, _, _):
            return resource
        case .joiningRelative(_, _, let resource, _, _, _):
            return resource
        case .joiningAbsolute(_, _, let resource, _, _, _):
            return resource
        }
    }
}
