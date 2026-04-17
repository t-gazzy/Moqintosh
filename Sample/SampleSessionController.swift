//
//  SampleSessionController.swift
//  Sample
//
//  Created by Codex on 2026/04/11.
//

import Foundation
import Observation
import Moqintosh

@MainActor
@Observable
final class SampleSessionController {

    var statusText: String
    var publishNamespaceText: String
    var subscribeNamespaceText: String
    var subscribeTrackNameText: String
    var advertisedNamespaceOptions: [String]
    var remotePublishedNamespaceOptions: [String]
    var selectedRemotePublishedNamespace: String
    var eventMessages: [String]
    var receivedMessages: [String]
    var isWorking: Bool

    private let configuration: SampleConfiguration
    private let session: Session
    private let publisher: Publisher
    private let subscriber: Subscriber
    private var delegateProxy: SampleSessionDelegateProxy
    private var streamEventPrinter: SampleStreamEventPrinter
    private var datagramEventPrinter: SampleDatagramEventPrinter
    private var advertisedNamespaces: [String: TrackNamespace]
    private var remotePublishedNamespaces: [String: TrackNamespace]
    private var publishedTrack: PublishedTrack?
    private var subscribedTrack: Subscription?
    private var streamSenderFactory: StreamSenderFactory?
    private var datagramSender: DatagramSender?
    private var currentStreamSender: StreamSender?
    private var currentStreamSenderGroupID: UInt64?
    private var streamReceiverFactory: StreamReceiverFactory?
    private var datagramReceiver: DatagramReceiver?
    private var streamSendTask: Task<Void, Never>?
    private var datagramSendTask: Task<Void, Never>?
    private var nextStreamGroupID: UInt64
    private var nextStreamObjectID: UInt64
    private var nextDatagramGroupID: UInt64
    private var nextDatagramObjectID: UInt64

    convenience init(session: Session) {
        self.init(session: session, configuration: SampleConfiguration())
    }

    init(session: Session, configuration: SampleConfiguration) {
        self.statusText = "Connected"
        self.publishNamespaceText = ""
        self.subscribeNamespaceText = ""
        self.subscribeTrackNameText = ""
        self.advertisedNamespaceOptions = []
        self.remotePublishedNamespaceOptions = []
        self.selectedRemotePublishedNamespace = ""
        self.eventMessages = []
        self.receivedMessages = []
        self.isWorking = false
        self.configuration = configuration
        self.session = session
        self.publisher = session.makePublisher()
        self.subscriber = session.makeSubscriber()
        self.delegateProxy = SampleSessionDelegateProxy(
            configuration: configuration,
            onEvent: { _ in },
            onRemotePublishedNamespace: { _ in },
            onIncomingSubscribe: { _ in }
        )
        self.streamEventPrinter = SampleStreamEventPrinter(
            configuration: configuration,
            onEvent: { _ in },
            onReceivedData: { _ in }
        )
        self.datagramEventPrinter = SampleDatagramEventPrinter(
            configuration: configuration,
            onReceivedData: { _ in }
        )
        self.advertisedNamespaces = [:]
        self.remotePublishedNamespaces = [:]
        self.publishedTrack = nil
        self.subscribedTrack = nil
        self.streamSenderFactory = nil
        self.datagramSender = nil
        self.currentStreamSender = nil
        self.currentStreamSenderGroupID = nil
        self.streamReceiverFactory = nil
        self.datagramReceiver = nil
        self.streamSendTask = nil
        self.datagramSendTask = nil
        self.nextStreamGroupID = 0
        self.nextStreamObjectID = 0
        self.nextDatagramGroupID = 0
        self.nextDatagramObjectID = 0

        let eventHandler: @Sendable (String) -> Void = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.appendEvent(message)
            }
        }
        let remotePublishedNamespaceHandler: @Sendable (TrackNamespace) -> Void = { [weak self] namespace in
            Task { @MainActor [weak self] in
                self?.registerRemotePublishedNamespace(namespace)
            }
        }
        let incomingSubscribeHandler: @Sendable (PublishedTrack) -> Void = { [weak self] publishedTrack in
            Task { @MainActor [weak self] in
                self?.startPublishing(to: publishedTrack)
            }
        }
        let receivedHandler: @Sendable (String) -> Void = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.appendReceivedMessage(message)
            }
        }
        self.delegateProxy = SampleSessionDelegateProxy(
            configuration: configuration,
            onEvent: eventHandler,
            onRemotePublishedNamespace: remotePublishedNamespaceHandler,
            onIncomingSubscribe: incomingSubscribeHandler
        )
        self.streamEventPrinter = SampleStreamEventPrinter(
            configuration: configuration,
            onEvent: eventHandler,
            onReceivedData: receivedHandler
        )
        self.datagramEventPrinter = SampleDatagramEventPrinter(
            configuration: configuration,
            onReceivedData: receivedHandler
        )
        self.session.delegate = delegateProxy
    }

    var canSubscribeTrack: Bool {
        !selectedRemotePublishedNamespace.isEmpty
    }

    var canSendStream: Bool {
        streamSenderFactory != nil && streamSendTask == nil
    }

    var canSendDatagram: Bool {
        datagramSender != nil && datagramSendTask == nil
    }

    func publishNamespace() async {
        guard let namespace: TrackNamespace = configuration.makeNamespace(from: publishNamespaceText) else {
            appendEvent("Invalid publish namespace")
            return
        }
        await performOperation(status: "Publishing namespace...") {
            try await self.publisher.publishNamespace(trackNamespace: namespace)
            self.registerAdvertisedNamespace(namespace)
            self.delegateProxy.registerAdvertisedNamespace(namespace)
            let namespaceText: String = self.configuration.makeNamespaceString(from: namespace)
            self.publishNamespaceText = namespaceText
            self.appendEvent("Published namespace: \(namespaceText)")
        }
    }

    func subscribeNamespace() async {
        guard let namespace: TrackNamespace = configuration.makeNamespace(from: subscribeNamespaceText) else {
            appendEvent("Invalid subscribe namespace")
            return
        }
        await performOperation(status: "Subscribing namespace...") {
            try await self.subscriber.subscribeNamespace(namespacePrefix: namespace)
            let namespaceText: String = self.configuration.makeNamespaceString(from: namespace)
            self.subscribeNamespaceText = namespaceText
            self.appendEvent("Subscribed namespace: \(namespaceText)")
        }
    }

    func subscribeTrack() async {
        guard let namespace: TrackNamespace = remotePublishedNamespaces[selectedRemotePublishedNamespace] else {
            appendEvent("No remote namespace selected")
            return
        }
        guard let resource: TrackResource = configuration.makeTrackResource(
            namespace: namespace,
            trackName: subscribeTrackNameText
        ) else {
            appendEvent("Invalid subscribe track name")
            return
        }
        await performOperation(status: "Subscribing track...") {
            let subscription: Subscription = try await self.subscriber.subscribe(resource: resource)
            let streamReceiverFactory: StreamReceiverFactory = self.subscriber.makeStreamReceiverFactory(for: subscription)
            let datagramReceiver: DatagramReceiver = self.subscriber.makeDatagramReceiver(for: subscription)
            streamReceiverFactory.delegate = self.streamEventPrinter
            datagramReceiver.delegate = self.datagramEventPrinter
            self.subscribedTrack = subscription
            self.streamReceiverFactory = streamReceiverFactory
            self.datagramReceiver = datagramReceiver
            self.appendEvent("Subscribed track: \(self.describe(resource: resource))")
        }
    }

    private func startPublishing(to publishedTrack: PublishedTrack) {
        stopSendLoops()
        self.publishedTrack = publishedTrack
        self.streamSenderFactory = publisher.makeStreamSenderFactory(for: publishedTrack)
        self.datagramSender = publisher.makeDatagramSender(for: publishedTrack)
        self.currentStreamSender = nil
        self.currentStreamSenderGroupID = nil
        self.nextStreamGroupID = 0
        self.nextStreamObjectID = 0
        self.nextDatagramGroupID = 0
        self.nextDatagramObjectID = 0
        self.appendEvent("Publishing became ready: \(describe(resource: publishedTrack.resource))")
    }

    func sendStreamTimestamp() async {
        guard let streamSenderFactory else {
            appendEvent("No published track is ready for stream sending")
            return
        }
        guard streamSendTask == nil else { return }
        appendEvent("Started stream timer")
        streamSendTask = Task { [weak self] in
            guard let self else { return }
            await self.runStreamSendLoop(streamSenderFactory: streamSenderFactory)
        }
    }

    func sendDatagramTimestamp() async {
        guard let datagramSender else {
            appendEvent("No published track is ready for datagram sending")
            return
        }
        guard datagramSendTask == nil else { return }
        appendEvent("Started datagram timer")
        datagramSendTask = Task { [weak self] in
            guard let self else { return }
            await self.runDatagramSendLoop(datagramSender: datagramSender)
        }
    }

    private func runStreamSendLoop(streamSenderFactory: StreamSenderFactory) async {
        while !Task.isCancelled {
            await sendNextStreamObject(streamSenderFactory: streamSenderFactory)
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                break
            }
        }
        streamSendTask = nil
    }

    private func runDatagramSendLoop(datagramSender: DatagramSender) async {
        while !Task.isCancelled {
            await sendNextDatagram(datagramSender: datagramSender)
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                break
            }
        }
        datagramSendTask = nil
    }

    private func sendNextStreamObject(streamSenderFactory: StreamSenderFactory) async {
        let groupID: UInt64 = nextStreamGroupID
        let objectID: UInt64 = nextStreamObjectID
        let endOfGroup: Bool = objectID == 9
        let payload: ReadOnlyBytes = configuration.makePayload()
        do {
            let sender: StreamSender
            if currentStreamSenderGroupID == groupID, let currentStreamSender {
                sender = currentStreamSender
            } else {
                sender = try await streamSenderFactory.makeSender(groupID: groupID)
                currentStreamSender = sender
                currentStreamSenderGroupID = groupID
            }
            try await sender.send(
                objectID: objectID,
                endOfGroup: endOfGroup,
                content: .payload(payload)
            )
            advanceStreamCounters()
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
            appendEvent("Stream send failed: \(error)")
            streamSendTask?.cancel()
        }
    }

    private func sendNextDatagram(datagramSender: DatagramSender) async {
        let groupID: UInt64 = nextDatagramGroupID
        let objectID: UInt64 = nextDatagramObjectID
        let payload: ReadOnlyBytes = configuration.makePayload()
        do {
            try await datagramSender.send(
                groupID: groupID,
                objectID: .explicit(objectID),
                content: .payload(payload)
            )
            advanceDatagramCounters()
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
            appendEvent("Datagram send failed: \(error)")
            datagramSendTask?.cancel()
        }
    }

    private func stopSendLoops() {
        streamSendTask?.cancel()
        datagramSendTask?.cancel()
        streamSendTask = nil
        datagramSendTask = nil
    }

    private func registerRemotePublishedNamespace(_ prefix: TrackNamespace) {
        let namespaceText: String = configuration.makeNamespaceString(from: prefix)
        remotePublishedNamespaces[namespaceText] = prefix
        if !remotePublishedNamespaceOptions.contains(namespaceText) {
            remotePublishedNamespaceOptions.append(namespaceText)
            remotePublishedNamespaceOptions.sort()
        }
        if selectedRemotePublishedNamespace.isEmpty {
            selectedRemotePublishedNamespace = namespaceText
        }
    }

    private func registerAdvertisedNamespace(_ namespace: TrackNamespace) {
        let namespaceText: String = configuration.makeNamespaceString(from: namespace)
        advertisedNamespaces[namespaceText] = namespace
        if !advertisedNamespaceOptions.contains(namespaceText) {
            advertisedNamespaceOptions.append(namespaceText)
            advertisedNamespaceOptions.sort()
        }
    }

    private func describe(resource: TrackResource) -> String {
        let namespaceText: String = configuration.makeNamespaceString(from: resource.trackNamespace)
        let trackNameText: String = String(data: resource.trackName, encoding: .utf8) ?? "<binary>"
        return "\(namespaceText)/\(trackNameText)"
    }

    private func performOperation(
        status: String,
        operation: @MainActor @escaping () async throws -> Void
    ) async {
        guard !isWorking else { return }
        isWorking = true
        statusText = status
        do {
            try await operation()
            statusText = "Ready"
        } catch {
            statusText = "Failed: \(error.localizedDescription)"
            appendEvent("Operation failed: \(error)")
        }
        isWorking = false
    }

    private func advanceStreamCounters() {
        nextStreamObjectID += 1
        if nextStreamObjectID == 10 {
            nextStreamGroupID += 1
            nextStreamObjectID = 0
            currentStreamSender = nil
            currentStreamSenderGroupID = nil
        }
    }

    private func advanceDatagramCounters() {
        nextDatagramObjectID += 1
        if nextDatagramObjectID == 10 {
            nextDatagramGroupID += 1
            nextDatagramObjectID = 0
        }
    }

    private func appendEvent(_ message: String) {
        print(message)
        eventMessages.insert(message, at: 0)
        if eventMessages.count > 50 {
            eventMessages.removeLast(eventMessages.count - 50)
        }
    }

    private func appendReceivedMessage(_ message: String) {
        print(message)
        receivedMessages.insert(message, at: 0)
        if receivedMessages.count > 50 {
            receivedMessages.removeLast(receivedMessages.count - 50)
        }
    }
}
