//
//  CallApplicationCoordinator.swift
//  CallApplicationSample
//
//  Created by Codex on 2026/04/22.
//

import AVFoundation
import Foundation
import Moqintosh
import RealtimeMediaKit

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class CallApplicationCoordinator: NSObject, CallApplicationCoordinating {
    private actor MediaHistoryStore {
        struct StoredPacket {
            let packet: TimedMediaPacket

            var location: Location {
                Location(group: 0, object: packet.sequenceNumber)
            }
        }

        private var storage: [String: [StoredPacket]]

        init() {
            self.storage = [:]
        }

        func append(packet: TimedMediaPacket, for resourceKey: String) {
            storage[resourceKey, default: []].append(StoredPacket(packet: packet))
        }

        func packets(for resourceKey: String) -> [StoredPacket] {
            storage[resourceKey, default: []]
        }

        func packets(for resourceKey: String, start: Location, end: Location) -> [StoredPacket] {
            storage[resourceKey, default: []].filter { storedPacket in
                storedPacket.location.group >= start.group &&
                    storedPacket.location.group <= end.group &&
                    storedPacket.location.object >= start.object &&
                    storedPacket.location.object <= end.object
            }
        }

        func endLocation(for resourceKey: String) -> Location? {
            storage[resourceKey, default: []].last?.location
        }
    }

    private final class HistoryRecordingPacketSender: RealtimeMediaPacketSender {
        private let sender: any RealtimeMediaPacketSender
        private let historyStore: MediaHistoryStore
        private let resourceKey: String

        init(sender: any RealtimeMediaPacketSender, historyStore: MediaHistoryStore, resourceKey: String) {
            self.sender = sender
            self.historyStore = historyStore
            self.resourceKey = resourceKey
        }

        func send(_ packet: TimedMediaPacket) async throws {
            try await sender.send(packet)
            await historyStore.append(packet: packet, for: resourceKey)
        }
    }

    private final class ActiveSendSession {
        let requestID: UInt64
        let kind: CallApplicationPresentationState.TrackKind
        let finishHandler: @MainActor () async -> Void

        init(
            requestID: UInt64,
            kind: CallApplicationPresentationState.TrackKind,
            finishHandler: @escaping @MainActor () async -> Void
        ) {
            self.requestID = requestID
            self.kind = kind
            self.finishHandler = finishHandler
        }

        @MainActor
        func finish() async {
            await finishHandler()
        }
    }

    private final class RemoteTrackSession {
        let subscription: Moqintosh.Subscription
        let kind: CallApplicationPresentationState.TrackKind
        #if canImport(UIKit)
        let renderView: VideoRenderView?
        #endif
        var datagramHandler: AnyObject?
        var streamHandlers: [AnyObject]
        var datagramReceiveHandler: RealtimeMediaReceivingHandler?
        var streamAcceptTask: Task<Void, Never>?

        init(
            subscription: Moqintosh.Subscription,
            kind: CallApplicationPresentationState.TrackKind
        ) {
            self.subscription = subscription
            self.kind = kind
            #if canImport(UIKit)
            if kind == .video {
                self.renderView = VideoRenderView()
            } else {
                self.renderView = nil
            }
            #endif
            self.streamHandlers = []
        }

        func finish() {
            datagramReceiveHandler?.finish()
            streamAcceptTask?.cancel()
            streamHandlers.removeAll(keepingCapacity: false)
            datagramHandler = nil
            #if canImport(UIKit)
            renderView?.flushAndRemoveImage()
            #endif
        }
    }

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

    private let historyStore: MediaHistoryStore
    private let audioFormat: AudioFormat
    private let videoFormat: VideoFormat
    private let iso8601Formatter: ISO8601DateFormatter

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

    private var remoteTrackSessions: [UInt64: RemoteTrackSession]
    private var activeSendSessions: [UInt64: ActiveSendSession]
    private var activeFetchTasks: [UInt64: Task<Void, Never>]
    private var playbackDevice: SystemAudioDevice?
    private var playbackBuffer: AudioPlaybackBuffer?
    private var captureDevice: SystemAudioDevice?
    private var cameraSource: CameraVideoSource?
    private var cameraTask: Task<Void, Never>?

    override init() {
        self.historyStore = MediaHistoryStore()
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
        self.remoteTrackSessions = [:]
        self.activeSendSessions = [:]
        self.activeFetchTasks = [:]
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

        await stopSendSessions(for: record.kind)

        do {
            let resourceKey: String = self.resourceKey(for: record.publishedTrack.resource)
            let packetSender: any RealtimeMediaPacketSender
            switch mode {
            case .stream:
                let senderFactory: StreamSenderFactory = publisher.makeStreamSenderFactory(for: record.publishedTrack)
                let streamSender: StreamSender = try await senderFactory.makeSender(groupID: 0)
                packetSender = HistoryRecordingPacketSender(
                    sender: MoqintoshStreamMediaSender(sender: streamSender),
                    historyStore: historyStore,
                    resourceKey: resourceKey
                )
            case .datagram:
                let datagramSender: DatagramSender = publisher.makeDatagramSender(for: record.publishedTrack)
                packetSender = HistoryRecordingPacketSender(
                    sender: MoqintoshDatagramMediaSender(sender: datagramSender, groupID: 0),
                    historyStore: historyStore,
                    resourceKey: resourceKey
                )
            }

            switch record.kind {
            case .video:
                try await startVideoSending(
                    packetSender: packetSender,
                    requestID: requestID,
                    kind: record.kind
                )
            case .audio:
                try await startAudioSending(
                    packetSender: packetSender,
                    requestID: requestID,
                    kind: record.kind
                )
            case .data:
                startDataSending(
                    packetSender: packetSender,
                    requestID: requestID,
                    kind: record.kind
                )
            }
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
            let task: Task<Void, Never> = Task { [weak self] in
                await self?.consumeFetch(for: record)
            }
            activeFetchTasks[record.fetchSubscription.requestID] = task
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
            activeFetchTasks[requestID]?.cancel()
            activeFetchTasks.removeValue(forKey: requestID)
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

    #if canImport(UIKit)
    func videoRenderView(for remoteTrackID: UInt64?) -> VideoRenderView? {
        guard let remoteTrackID else {
            return nil
        }
        return remoteTrackSessions[remoteTrackID]?.renderView
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
            await stopSendSession(requestID: update.requestID)
        }
    }

    func session(_ session: Session, didReceiveUnsubscribe requestID: UInt64) async {
        appendEvent("Received unsubscribe for requestID=\(requestID)")
        inboundSubscriptionRecords.removeAll { $0.publishedTrack.requestID == requestID }
        syncPresentationCollections()
        await stopSendSession(requestID: requestID)
    }

    func session(_ session: Session, didReceiveFetch request: FetchRequest) async -> FetchDecision {
        let requestResource: TrackResource = resource(from: request)
        let resourceKey: String = self.resourceKey(for: requestResource)
        guard let endLocation: Location = await historyStore.endLocation(for: resourceKey) else {
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
        let task: Task<Void, Never> = Task { [weak self] in
            await self?.sendFetchResponse(
                publisher: publisher,
                request: request,
                resourceKey: resourceKey
            )
        }
        activeFetchTasks[request.requestID] = task
        return .accept(response)
    }

    func session(_ session: Session, didReceiveFetchCancel requestID: UInt64) async {
        appendEvent("Received fetch_cancel for requestID=\(requestID)")
        activeFetchTasks[requestID]?.cancel()
        activeFetchTasks.removeValue(forKey: requestID)
    }

    func session(_ session: Session, didReceiveTrackStatus request: TrackStatusRequest) async -> TrackStatusDecision {
        let requestResource: TrackResource = request.resource
        let resourceKey: String = self.resourceKey(for: requestResource)
        guard let endLocation: Location = await historyStore.endLocation(for: resourceKey) else {
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

    func stopSendSessions(for kind: CallApplicationPresentationState.TrackKind) async {
        let requestIDs: [UInt64] = activeSendSessions.values
            .filter { $0.kind == kind }
            .map(\.requestID)
        for requestID in requestIDs {
            await stopSendSession(requestID: requestID)
        }
    }

    func stopSendSession(requestID: UInt64) async {
        guard let activeSession: ActiveSendSession = activeSendSessions.removeValue(forKey: requestID) else {
            return
        }
        await activeSession.finish()
    }

    func startVideoSending(
        packetSender: any RealtimeMediaPacketSender,
        requestID: UInt64,
        kind: CallApplicationPresentationState.TrackKind
    ) async throws {
        if cameraSource == nil {
            cameraSource = try CameraVideoSource(
                configuration: CameraVideoConfiguration(
                    position: .front,
                    format: videoFormat
                )
            )
        }
        guard let cameraSource else {
            throw NSError(
                domain: "CallApplicationSample",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Camera source unavailable"]
            )
        }

        let sendingHandler: VideoEncodedPacketSendingHandler = VideoEncodedPacketSendingHandler(sender: packetSender)
        let encoder: H264VideoEncoder = try H264VideoEncoder(
            configuration: H264EncoderConfiguration(
                inputFormat: videoFormat,
                bitrate: 500_000,
                keyFrameInterval: 30
            )
        )

        try await cameraSource.start()
        cameraTask = Task { [weak self] in
            do {
                for try await frame in cameraSource.frames {
                    let packet: VideoEncodedPacket = try await encoder.encode(frame)
                    sendingHandler.handleEncodedPacket(packet)
                }
            } catch {
                await self?.handleBackgroundError(error, context: "Video send")
            }
        }

        activeSendSessions[requestID] = ActiveSendSession(
            requestID: requestID,
            kind: kind
        ) { [weak self] in
            self?.cameraTask?.cancel()
            self?.cameraTask = nil
            if let cameraSource: CameraVideoSource = self?.cameraSource {
                try? await cameraSource.stop()
            }
        }
    }

    func startAudioSending(
        packetSender: any RealtimeMediaPacketSender,
        requestID: UInt64,
        kind: CallApplicationPresentationState.TrackKind
    ) async throws {
        let sendingHandler: AudioEncodedPacketSendingHandler = AudioEncodedPacketSendingHandler(sender: packetSender)
        let encoder: OpusAudioEncoder = try OpusAudioEncoder(
            configuration: OpusEncoderConfiguration(
                inputFormat: audioFormat,
                frameCountPerPacket: 960,
                bitrate: 32_000
            )
        )
        if captureDevice == nil {
            captureDevice = try SystemAudioDevice(
                configuration: AudioDeviceConfiguration(
                    format: audioFormat,
                    backend: .voiceProcessingIO,
                    inputProcessing: .voiceProcessed,
                    inputEnabled: true,
                    outputEnabled: false
                )
            )
        }
        guard let captureDevice else {
            throw NSError(
                domain: "CallApplicationSample",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Audio capture device unavailable"]
            )
        }

        captureDevice.pipeline.removeAllProcessors()
        captureDevice.pipeline.appendProcessor(
            AudioEncodingProcessor(
                encoder: encoder,
                sink: sendingHandler
            )
        )
        try captureDevice.start()

        activeSendSessions[requestID] = ActiveSendSession(
            requestID: requestID,
            kind: kind
        ) { [weak self] in
            self?.captureDevice?.pipeline.removeAllProcessors()
            try? self?.captureDevice?.stop()
        }
    }

    func startDataSending(
        packetSender: any RealtimeMediaPacketSender,
        requestID: UInt64,
        kind: CallApplicationPresentationState.TrackKind
    ) {
        let task: Task<Void, Never> = Task { [weak self] in
            var sequenceNumber: UInt64 = 0
            while !Task.isCancelled {
                let timestampText: String = self?.iso8601Formatter.string(from: Date()) ?? ""
                let packet: TimedMediaPacket = TimedMediaPacket(
                    sequenceNumber: sequenceNumber,
                    timestamp: Int64(Date().timeIntervalSince1970 * 1000.0),
                    duration: 1,
                    payload: Data(timestampText.utf8)
                )
                do {
                    try await packetSender.send(packet)
                } catch {
                    await self?.handleBackgroundError(error, context: "Data send")
                    return
                }
                sequenceNumber += 1
                try? await Task.sleep(for: .seconds(1))
            }
        }

        activeSendSessions[requestID] = ActiveSendSession(
            requestID: requestID,
            kind: kind
        ) {
            task.cancel()
        }
    }

    func ensurePlaybackDevice() throws -> AudioPlaybackBuffer {
        if let playbackBuffer {
            return playbackBuffer
        }
        let buffer: AudioPlaybackBuffer = AudioPlaybackBuffer(format: audioFormat)
        let device: SystemAudioDevice = try SystemAudioDevice(
            configuration: AudioDeviceConfiguration(
                format: audioFormat,
                backend: .remoteIO,
                inputProcessing: .raw,
                inputEnabled: false,
                outputEnabled: true
            )
        )
        device.renderSource = buffer
        try device.start()
        playbackDevice = device
        playbackBuffer = buffer
        return buffer
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
            remoteTrackSessions[subscription.requestID] = RemoteTrackSession(
                subscription: subscription,
                kind: record.kind
            )
            syncPresentationCollections()
            try await startReceiving(for: record)
            appendEvent("Subscribed remote track \(record.presentation.displayName)")
        } catch {
            appendEvent("Failed to subscribe remote track: \(error)")
        }
    }

    func finishRemoteTrack(requestID: UInt64) {
        remoteTrackSessions[requestID]?.finish()
        remoteTrackSessions.removeValue(forKey: requestID)
        remoteTrackRecords.removeAll { $0.subscription.requestID == requestID }
        syncPresentationCollections()
    }

    private func startReceiving(for record: RemoteTrackRecord) async throws {
        guard let subscriber else {
            return
        }
        guard let remoteTrackSession: RemoteTrackSession = remoteTrackSessions[record.subscription.requestID] else {
            return
        }

        let datagramReceiver: DatagramReceiver = subscriber.makeDatagramReceiver(for: record.subscription)
        switch record.kind {
        case .video:
            #if canImport(UIKit)
            let datagramHandler: VideoEncodedPacketReceivingHandler = VideoEncodedPacketReceivingHandler(
                receiver: MoqintoshDatagramMediaReceiver(receiver: datagramReceiver),
                decoder: H264VideoDecoder(),
                sink: remoteTrackSession.renderView
            )
            remoteTrackSession.datagramHandler = datagramHandler
            #endif
        case .audio:
            let playbackBuffer: AudioPlaybackBuffer = try ensurePlaybackDevice()
            let datagramHandler: AudioEncodedPacketReceivingHandler = AudioEncodedPacketReceivingHandler(
                receiver: MoqintoshDatagramMediaReceiver(receiver: datagramReceiver),
                decoder: try OpusAudioDecoder(outputFormat: audioFormat),
                outputFormat: audioFormat,
                sink: playbackBuffer
            )
            remoteTrackSession.datagramHandler = datagramHandler
        case .data:
            let receiveHandler: RealtimeMediaReceivingHandler = RealtimeMediaReceivingHandler(
                receiver: MoqintoshDatagramMediaReceiver(receiver: datagramReceiver),
                packetHandler: { [weak self] packet in
                    await self?.handleIncomingDataPacket(
                        packet,
                        resource: record.subscription.publishedTrack.resource
                    )
                }
            )
            remoteTrackSession.datagramReceiveHandler = receiveHandler
        }

        let streamFactory: StreamReceiverFactory = subscriber.makeStreamReceiverFactory(for: record.subscription)
        remoteTrackSession.streamAcceptTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let streamReceiver: StreamReceiver = await streamFactory.accept() else {
                    return
                }
                await self?.attachStreamReceiver(
                    streamReceiver,
                    to: record.subscription.requestID
                )
            }
        }
    }

    func attachStreamReceiver(_ streamReceiver: StreamReceiver, to remoteTrackID: UInt64) async {
        guard let remoteTrackSession: RemoteTrackSession = remoteTrackSessions[remoteTrackID] else {
            return
        }

        switch remoteTrackSession.kind {
        case .video:
            #if canImport(UIKit)
            let handler: VideoEncodedPacketReceivingHandler = VideoEncodedPacketReceivingHandler(
                receiver: MoqintoshStreamMediaReceiver(receiver: streamReceiver),
                decoder: H264VideoDecoder(),
                sink: remoteTrackSession.renderView
            )
            remoteTrackSession.streamHandlers.append(handler)
            #endif
        case .audio:
            do {
                let playbackBuffer: AudioPlaybackBuffer = try ensurePlaybackDevice()
                let handler: AudioEncodedPacketReceivingHandler = AudioEncodedPacketReceivingHandler(
                    receiver: MoqintoshStreamMediaReceiver(receiver: streamReceiver),
                    decoder: try OpusAudioDecoder(outputFormat: audioFormat),
                    outputFormat: audioFormat,
                    sink: playbackBuffer
                )
                remoteTrackSession.streamHandlers.append(handler)
            } catch {
                appendEvent("Failed to attach audio stream receiver: \(error)")
            }
        case .data:
            let receiveHandler: RealtimeMediaReceivingHandler = RealtimeMediaReceivingHandler(
                receiver: MoqintoshStreamMediaReceiver(receiver: streamReceiver),
                packetHandler: { [weak self] packet in
                    await self?.handleIncomingDataPacket(
                        packet,
                        resource: remoteTrackSession.subscription.publishedTrack.resource
                    )
                }
            )
            remoteTrackSession.streamHandlers.append(receiveHandler)
        }
    }

    func handleIncomingDataPacket(_ packet: TimedMediaPacket, resource: TrackResource) async {
        appendDataLog(resource: resource, packet: packet)
    }

    private func consumeFetch(for record: ActiveFetchRecord) async {
        guard let subscriber else {
            return
        }
        let receiverFactory: FetchReceiverFactory = subscriber.makeFetchReceiverFactory(for: record.fetchSubscription)
        while !Task.isCancelled {
            guard let fetchReceiver: FetchReceiver = await receiverFactory.accept() else {
                return
            }
            await consume(
                fetchReceiver: fetchReceiver,
                kind: record.kind,
                resource: record.fetchSubscription.resource
            )
        }
    }

    func consume(
        fetchReceiver: FetchReceiver,
        kind: CallApplicationPresentationState.TrackKind,
        resource: TrackResource
    ) async {
        do {
            while let object: SubgroupObject = try await fetchReceiver.receive() {
                switch object.content {
                case .payload(let payload):
                    let packet: TimedMediaPacket = try RealtimeMediaPacketPayloadCodec.decode(
                        sequenceNumber: object.objectID,
                        payload: payload.materialize()
                    )
                    switch kind {
                    case .video:
                        #if canImport(UIKit)
                        if let videoRecord: RemoteTrackRecord = remoteTrackRecords.first(where: { $0.kind == .video }),
                           let renderView: VideoRenderView = remoteTrackSessions[videoRecord.subscription.requestID]?.renderView {
                            let decodedFrame: VideoFrame = try await H264VideoDecoder().decode(
                                try VideoEncodedPacketPayloadCodec.decode(packet)
                            )
                            try await renderView.handleDecodedFrame(decodedFrame)
                        }
                        #endif
                    case .audio:
                        let playbackBuffer: AudioPlaybackBuffer = try ensurePlaybackDevice()
                        let decodedFrame: AudioFrame = try OpusAudioDecoder(outputFormat: audioFormat).decode(
                            AudioEncodedPacket(
                                payload: packet.payload,
                                frameCount: Int(packet.duration),
                                sourceFormat: audioFormat
                            )
                        )
                        playbackBuffer.append(decodedFrame)
                    case .data:
                        appendDataLog(resource: resource, packet: packet)
                    }
                case .status:
                    break
                }
            }
        } catch {
            appendEvent("Fetch receive failed: \(error)")
        }
    }

    func sendFetchResponse(
        publisher: Moqintosh.Publisher,
        request: FetchRequest,
        resourceKey: String
    ) async {
        do {
            let sender: FetchSender = try await publisher.makeFetchSender(for: request)
            let packets: [MediaHistoryStore.StoredPacket]
            switch request {
            case .standalone(_, _, _, _, let start, let end):
                packets = await historyStore.packets(for: resourceKey, start: start, end: end)
            case .joiningRelative:
                packets = await historyStore.packets(for: resourceKey)
            case .joiningAbsolute(_, _, _, _, _, let startGroup):
                let start: Location = Location(group: startGroup, object: 0)
                let end: Location = await historyStore.endLocation(for: resourceKey) ?? Location(group: startGroup, object: 0)
                packets = await historyStore.packets(for: resourceKey, start: start, end: end)
            }

            for (index, storedPacket) in packets.enumerated() {
                let isLast: Bool = index == packets.count - 1
                try await sender.send(
                    groupID: 0,
                    subgroupID: 0,
                    objectID: storedPacket.packet.sequenceNumber,
                    publisherPriority: 0,
                    endOfFetch: isLast,
                    content: .payload(RealtimeMediaPacketPayloadCodec.encode(storedPacket.packet))
                )
            }
            activeFetchTasks.removeValue(forKey: request.requestID)
        } catch {
            appendEvent("Failed to send fetch response: \(error)")
        }
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

    func handleBackgroundError(_ error: Error, context: String) async {
        appendEvent("\(context) error: \(error)")
    }
}
