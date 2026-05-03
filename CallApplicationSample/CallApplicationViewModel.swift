//
//  CallApplicationViewModel.swift
//  CallApplicationSample
//
//  Created by Codex on 2026/04/22.
//

import Combine
import Foundation

#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
import RealtimeMediaKit
#endif

@MainActor
final class CallApplicationViewModel: ObservableObject {
    typealias DeliveryMode = CallApplicationPresentationState.DeliveryMode
    typealias TrackKind = CallApplicationPresentationState.TrackKind
    typealias NamespaceItem = CallApplicationPresentationState.NamespaceItem
    typealias PublishedTrackItem = CallApplicationPresentationState.PublishedTrackItem
    typealias InboundSubscriptionItem = CallApplicationPresentationState.InboundSubscriptionItem
    typealias RemoteTrackItem = CallApplicationPresentationState.RemoteTrackItem
    typealias RemoteVideoItem = CallApplicationPresentationState.RemoteVideoItem
    typealias ActiveFetchItem = CallApplicationPresentationState.ActiveFetchItem

    @Published var endpointAddress: String
    @Published var allowsUntrustedCertificates: Bool
    @Published var isControlPanelPresented: Bool
    @Published var publishNamespaceInput: String
    @Published var subscribeNamespaceInput: String
    @Published var selectedPublishedNamespaceID: UUID?
    @Published var selectedTrackKind: TrackKind
    @Published var publishForwardEnabled: Bool
    @Published var selectedRemoteVideoTrackID: UInt64?
    @Published var selectedFetchTrackID: UInt64?
    @Published var fetchStartObjectText: String
    @Published var fetchEndObjectText: String
    @Published private(set) var presentationState: CallApplicationPresentationState

    private let coordinator: any CallApplicationCoordinating

    init(coordinator: any CallApplicationCoordinating) {
        self.endpointAddress = "localhost:4433"
        self.allowsUntrustedCertificates = false
        self.isControlPanelPresented = false
        self.publishNamespaceInput = "call/room1"
        self.subscribeNamespaceInput = "call/room1"
        self.selectedPublishedNamespaceID = nil
        self.selectedTrackKind = .video
        self.publishForwardEnabled = true
        self.selectedRemoteVideoTrackID = nil
        self.selectedFetchTrackID = nil
        self.fetchStartObjectText = "0"
        self.fetchEndObjectText = "30"
        self.presentationState = CallApplicationPresentationState()
        self.coordinator = coordinator
        coordinator.delegate = self
    }

    var isConnected: Bool {
        presentationState.isConnected
    }

    var isConnecting: Bool {
        presentationState.isConnecting
    }

    var connectionErrorMessage: String? {
        presentationState.connectionErrorMessage
    }

    var connectedEndpointDescription: String {
        presentationState.connectedEndpointDescription
    }

    var activePublishedNamespaces: [NamespaceItem] {
        presentationState.activePublishedNamespaces
    }

    var activeSubscribedNamespaces: [NamespaceItem] {
        presentationState.activeSubscribedNamespaces
    }

    var localPublishedTracks: [PublishedTrackItem] {
        presentationState.localPublishedTracks
    }

    var inboundSubscriptionRequests: [InboundSubscriptionItem] {
        presentationState.inboundSubscriptionRequests
    }

    var remoteTracks: [RemoteTrackItem] {
        presentationState.remoteTracks
    }

    var remoteVideoTracks: [RemoteVideoItem] {
        presentationState.remoteVideoTracks
    }

    var activeFetchSubscriptions: [ActiveFetchItem] {
        presentationState.activeFetchSubscriptions
    }

    var dataLogLines: [String] {
        presentationState.dataLogLines
    }

    var eventLogLines: [String] {
        presentationState.eventLogLines
    }

    #if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
    var selectedVideoRenderView: VideoRenderView? {
        coordinator.videoRenderView(for: selectedRemoteVideoTrackID)
    }
    #else
    var selectedVideoRenderView: Any? {
        nil
    }
    #endif
}

extension CallApplicationViewModel {
    func connect() async {
        await coordinator.connect(
            endpointAddress: endpointAddress,
            allowsUntrustedCertificates: allowsUntrustedCertificates
        )
    }

    func publishNamespace() async {
        await coordinator.publishNamespace(input: publishNamespaceInput)
    }

    func subscribeNamespace() async {
        await coordinator.subscribeNamespace(input: subscribeNamespaceInput)
    }

    func publishTrack() async {
        await coordinator.publishTrack(
            selectedNamespaceID: selectedPublishedNamespaceID,
            trackKind: selectedTrackKind,
            forward: publishForwardEnabled
        )
    }

    func startSending(for requestID: UInt64, mode: DeliveryMode) async {
        await coordinator.startSending(requestID: requestID, mode: mode)
    }

    func publishDone(for requestID: UInt64) async {
        await coordinator.publishDone(requestID: requestID)
    }

    func publishNamespaceDone(for namespaceID: UUID) async {
        await coordinator.publishNamespaceDone(namespaceID: namespaceID)
    }

    func unsubscribeNamespace(_ namespaceID: UUID) async {
        await coordinator.unsubscribeNamespace(namespaceID: namespaceID)
    }

    func unsubscribeRemoteTrack(_ requestID: UInt64) async {
        await coordinator.unsubscribeRemoteTrack(requestID: requestID)
    }

    func fetchRemoteTrack() async {
        await coordinator.fetchRemoteTrack(
            selectedTrackID: selectedFetchTrackID,
            startObjectText: fetchStartObjectText,
            endObjectText: fetchEndObjectText
        )
    }

    func cancelFetch(_ requestID: UInt64) async {
        await coordinator.cancelFetch(requestID: requestID)
    }

    func sendGoAway() async {
        await coordinator.sendGoAway()
    }
}

extension CallApplicationViewModel: CallApplicationCoordinatorDelegate {
    func coordinator(
        _ coordinator: any CallApplicationCoordinating,
        didUpdate state: CallApplicationPresentationState
    ) {
        self.presentationState = state
        if selectedPublishedNamespaceID == nil {
            selectedPublishedNamespaceID = state.activePublishedNamespaces.first?.id
        }
        if selectedRemoteVideoTrackID == nil {
            selectedRemoteVideoTrackID = state.remoteVideoTracks.first?.id
        } else if !state.remoteVideoTracks.contains(where: { $0.id == selectedRemoteVideoTrackID }) {
            selectedRemoteVideoTrackID = state.remoteVideoTracks.first?.id
        }
        if selectedFetchTrackID == nil {
            selectedFetchTrackID = state.remoteTracks.first?.id
        } else if !state.remoteTracks.contains(where: { $0.id == selectedFetchTrackID }) {
            selectedFetchTrackID = state.remoteTracks.first?.id
        }
    }
}
