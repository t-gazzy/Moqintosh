//
//  CallApplicationMediaController.swift
//  CallApplicationSample
//
//  Created by Codex on 2026/04/22.
//

import Foundation
import Moqintosh
import RealtimeMediaKit

#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
import UIKit
#endif

@MainActor
final class CallApplicationMediaController {
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
        let eventTask: Task<Void, Never>
        let finishHandler: @MainActor () async -> Void

        init(
            requestID: UInt64,
            kind: CallApplicationPresentationState.TrackKind,
            eventTask: Task<Void, Never>,
            finishHandler: @escaping @MainActor () async -> Void
        ) {
            self.requestID = requestID
            self.kind = kind
            self.eventTask = eventTask
            self.finishHandler = finishHandler
        }

        @MainActor
        func finish() async {
            eventTask.cancel()
            await finishHandler()
        }
    }

    private final class RemoteTrackSession {
        let subscription: Moqintosh.Subscription
        let kind: CallApplicationPresentationState.TrackKind
        #if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
        let renderView: VideoRenderView?
        #endif
        var datagramHandler: AnyObject?
        var streamHandlers: [AnyObject]
        var eventTasks: [Task<Void, Never>]
        var datagramReceiveHandler: RealtimeMediaReceivingHandler?
        var streamAcceptTask: Task<Void, Never>?

        init(
            subscription: Moqintosh.Subscription,
            kind: CallApplicationPresentationState.TrackKind
        ) {
            self.subscription = subscription
            self.kind = kind
            #if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
            if kind == .video {
                self.renderView = VideoRenderView()
            } else {
                self.renderView = nil
            }
            #endif
            self.streamHandlers = []
            self.eventTasks = []
        }

        func finish() {
            datagramReceiveHandler?.finish()
            streamAcceptTask?.cancel()
            eventTasks.forEach { $0.cancel() }
            eventTasks.removeAll(keepingCapacity: false)
            streamHandlers.removeAll(keepingCapacity: false)
            datagramHandler = nil
            #if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
            renderView?.flushAndRemoveImage()
            #endif
        }
    }

    private let historyStore: MediaHistoryStore
    private let audioFormat: AudioFormat
    private let videoFormat: VideoFormat
    private let onEvent: @MainActor (String) -> Void
    private let onDataPacket: @MainActor (TrackResource, TimedMediaPacket) -> Void

    private var remoteTrackSessions: [UInt64: RemoteTrackSession]
    private var activeSendSessions: [UInt64: ActiveSendSession]
    private var activeFetchTasks: [UInt64: Task<Void, Never>]

    init(
        audioFormat: AudioFormat,
        videoFormat: VideoFormat,
        onEvent: @escaping @MainActor (String) -> Void,
        onDataPacket: @escaping @MainActor (TrackResource, TimedMediaPacket) -> Void
    ) {
        self.historyStore = MediaHistoryStore()
        self.audioFormat = audioFormat
        self.videoFormat = videoFormat
        self.onEvent = onEvent
        self.onDataPacket = onDataPacket
        self.remoteTrackSessions = [:]
        self.activeSendSessions = [:]
        self.activeFetchTasks = [:]
    }

    func makePacketSender(
        for publishedTrack: PublishedTrack,
        mode: CallApplicationPresentationState.DeliveryMode,
        resourceKey: String,
        publisher: Moqintosh.Publisher
    ) async throws -> any RealtimeMediaPacketSender {
        switch mode {
        case .stream:
            let senderFactory: StreamSenderFactory = publisher.makeStreamSenderFactory(for: publishedTrack)
            let streamSender: StreamSender = try await senderFactory.makeSender(groupID: 0)
            return HistoryRecordingPacketSender(
                sender: MoqintoshStreamMediaSender(sender: streamSender),
                historyStore: historyStore,
                resourceKey: resourceKey
            )
        case .datagram:
            let datagramSender: DatagramSender = publisher.makeDatagramSender(for: publishedTrack)
            return HistoryRecordingPacketSender(
                sender: MoqintoshDatagramMediaSender(sender: datagramSender, groupID: 0),
                historyStore: historyStore,
                resourceKey: resourceKey
            )
        }
    }

    func startSending(
        requestID: UInt64,
        kind: CallApplicationPresentationState.TrackKind,
        packetSender: any RealtimeMediaPacketSender
    ) async throws {
        switch kind {
        case .video:
            try await startVideoSending(packetSender: packetSender, requestID: requestID, kind: kind)
        case .audio:
            try await startAudioSending(packetSender: packetSender, requestID: requestID, kind: kind)
        case .data:
            startDataSending(packetSender: packetSender, requestID: requestID, kind: kind)
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

    func endLocation(for resourceKey: String) async -> Location? {
        await historyStore.endLocation(for: resourceKey)
    }

    func beginReceiving(
        subscription: Moqintosh.Subscription,
        kind: CallApplicationPresentationState.TrackKind,
        subscriber: Moqintosh.Subscriber
    ) async throws {
        remoteTrackSessions[subscription.requestID] = RemoteTrackSession(
            subscription: subscription,
            kind: kind
        )
        try await startReceiving(
            subscription: subscription,
            kind: kind,
            subscriber: subscriber
        )
    }

    func finishRemoteTrack(requestID: UInt64) {
        remoteTrackSessions[requestID]?.finish()
        remoteTrackSessions.removeValue(forKey: requestID)
    }

    func beginFetchReceiving(
        fetchSubscription: FetchSubscription,
        kind: CallApplicationPresentationState.TrackKind,
        subscriber: Moqintosh.Subscriber
    ) {
        let task: Task<Void, Never> = Task { [weak self] in
            await self?.consumeFetch(
                fetchSubscription: fetchSubscription,
                kind: kind,
                subscriber: subscriber
            )
        }
        activeFetchTasks[fetchSubscription.requestID] = task
    }

    func cancelFetchTask(requestID: UInt64) {
        activeFetchTasks[requestID]?.cancel()
        activeFetchTasks.removeValue(forKey: requestID)
    }

    func sendFetchResponse(
        publisher: Moqintosh.Publisher,
        request: FetchRequest,
        resourceKey: String
    ) async throws {
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
    }

    #if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
    func videoRenderView(for remoteTrackID: UInt64?) -> VideoRenderView? {
        guard let remoteTrackID else {
            return nil
        }
        return remoteTrackSessions[remoteTrackID]?.renderView
    }
    #endif
}

private extension CallApplicationMediaController {
    func startVideoSending(
        packetSender: any RealtimeMediaPacketSender,
        requestID: UInt64,
        kind: CallApplicationPresentationState.TrackKind
    ) async throws {
        let sender: VideoSender = try VideoSender(
            packetSender: packetSender,
            format: videoFormat
        )
        let eventTask: Task<Void, Never> = observeEvents(from: sender.events, context: "Video send")
        try await sender.start()

        activeSendSessions[requestID] = ActiveSendSession(
            requestID: requestID,
            kind: kind,
            eventTask: eventTask
        ) {
            try? await sender.stop()
        }
    }

    func startAudioSending(
        packetSender: any RealtimeMediaPacketSender,
        requestID: UInt64,
        kind: CallApplicationPresentationState.TrackKind
    ) async throws {
        let sender: AudioSender = try AudioSender(
            packetSender: packetSender,
            format: audioFormat
        )
        let eventTask: Task<Void, Never> = observeEvents(from: sender.events, context: "Audio send")
        try await sender.start()

        activeSendSessions[requestID] = ActiveSendSession(
            requestID: requestID,
            kind: kind,
            eventTask: eventTask
        ) {
            await sender.stop()
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
                let timestampText: String = ISO8601DateFormatter().string(from: Date())
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
            kind: kind,
            eventTask: Task<Void, Never> {}
        ) {
            task.cancel()
        }
    }

    func startReceiving(
        subscription: Moqintosh.Subscription,
        kind: CallApplicationPresentationState.TrackKind,
        subscriber: Moqintosh.Subscriber
    ) async throws {
        guard let remoteTrackSession: RemoteTrackSession = remoteTrackSessions[subscription.requestID] else {
            return
        }

        let datagramReceiver: DatagramReceiver = await subscriber.makeDatagramReceiver(for: subscription)
        switch kind {
        case .video:
            #if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
            let datagramHandler: VideoReceiver = VideoReceiver(
                packetReceiver: MoqintoshDatagramMediaReceiver(receiver: datagramReceiver),
                sink: remoteTrackSession.renderView!
            )
            remoteTrackSession.eventTasks.append(
                observeEvents(from: datagramHandler.events, context: "Video receive")
            )
            try await datagramHandler.start()
            remoteTrackSession.datagramHandler = datagramHandler
            #endif
        case .audio:
            let datagramHandler: AudioReceiver = try AudioReceiver(
                packetReceiver: MoqintoshDatagramMediaReceiver(receiver: datagramReceiver),
                outputFormat: audioFormat
            )
            remoteTrackSession.eventTasks.append(
                observeEvents(from: datagramHandler.events, context: "Audio receive")
            )
            try await datagramHandler.start()
            remoteTrackSession.datagramHandler = datagramHandler
        case .data:
            let receiveHandler: RealtimeMediaReceivingHandler = RealtimeMediaReceivingHandler(
                receiver: MoqintoshDatagramMediaReceiver(receiver: datagramReceiver),
                packetHandler: { [weak self] packet in
                    await self?.onDataPacket(subscription.publishedTrack.resource, packet)
                }
            )
            remoteTrackSession.datagramReceiveHandler = receiveHandler
        }

        let streamFactory: StreamReceiverFactory = await subscriber.makeStreamReceiverFactory(for: subscription)
        remoteTrackSession.streamAcceptTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let streamReceiver: StreamReceiver = await streamFactory.accept() else {
                    return
                }
                await self?.attachStreamReceiver(
                    streamReceiver,
                    to: subscription.requestID
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
            #if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
            let handler: VideoReceiver = VideoReceiver(
                packetReceiver: MoqintoshStreamMediaReceiver(receiver: streamReceiver),
                sink: remoteTrackSession.renderView!
            )
            remoteTrackSession.eventTasks.append(
                observeEvents(from: handler.events, context: "Video receive")
            )
            try? await handler.start()
            remoteTrackSession.streamHandlers.append(handler)
            #endif
        case .audio:
            do {
                let handler: AudioReceiver = try AudioReceiver(
                    packetReceiver: MoqintoshStreamMediaReceiver(receiver: streamReceiver),
                    outputFormat: audioFormat
                )
                remoteTrackSession.eventTasks.append(
                    observeEvents(from: handler.events, context: "Audio receive")
                )
                try await handler.start()
                remoteTrackSession.streamHandlers.append(handler)
            } catch {
                await handleBackgroundError(error, context: "Audio receive")
            }
        case .data:
            let receiveHandler: RealtimeMediaReceivingHandler = RealtimeMediaReceivingHandler(
                receiver: MoqintoshStreamMediaReceiver(receiver: streamReceiver),
                packetHandler: { [weak self] packet in
                    await self?.onDataPacket(
                        remoteTrackSession.subscription.publishedTrack.resource,
                        packet
                    )
                }
            )
            remoteTrackSession.streamHandlers.append(receiveHandler)
        }
    }

    func consumeFetch(
        fetchSubscription: FetchSubscription,
        kind: CallApplicationPresentationState.TrackKind,
        subscriber: Moqintosh.Subscriber
    ) async {
        let receiverFactory: FetchReceiverFactory = await subscriber.makeFetchReceiverFactory(for: fetchSubscription)
        while !Task.isCancelled {
            guard let fetchReceiver: FetchReceiver = await receiverFactory.accept() else {
                return
            }
            await consume(
                fetchReceiver: fetchReceiver,
                kind: kind,
                resource: fetchSubscription.resource
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
                        #if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
                        if let firstVideoTrackID: UInt64 = remoteTrackSessions.first(where: { $0.value.kind == .video })?.key,
                           let renderView: VideoRenderView = remoteTrackSessions[firstVideoTrackID]?.renderView {
                            let decodedFrame: VideoFrame = try await H264VideoDecoder().decode(
                                try VideoEncodedPacketPayloadCodec.decode(packet)
                            )
                            try await renderView.handleDecodedFrame(decodedFrame)
                        }
                        #endif
                    case .audio:
                        let playbackBuffer: AudioPlaybackBuffer = try SharedAudioDevice.shared.acquirePlaybackBuffer(
                            format: audioFormat
                        )
                        defer {
                            SharedAudioDevice.shared.releasePlayback()
                        }
                        let decodedFrame: AudioFrame = try OpusAudioDecoder(outputFormat: audioFormat).decode(
                            AudioEncodedPacket(
                                payload: packet.payload,
                                frameCount: Int(packet.duration),
                                sourceFormat: audioFormat
                            )
                        )
                        playbackBuffer.append(decodedFrame)
                    case .data:
                        onDataPacket(resource, packet)
                    }
                case .status:
                    break
                }
            }
        } catch {
            await handleBackgroundError(error, context: "Fetch receive")
        }
    }

    func observeEvents(
        from events: AsyncStream<RealtimeMediaLifecycleEvent>,
        context: String
    ) -> Task<Void, Never> {
        Task { [weak self] in
            for await event in events {
                guard !Task.isCancelled else {
                    return
                }
                switch event {
                case .didStart, .didStop:
                    break
                case .didFail(let error):
                    await self?.handleBackgroundError(error, context: context)
                }
            }
        }
    }

    func handleBackgroundError(_ error: Error, context: String) async {
        onEvent("\(context) error: \(error)")
    }
}
