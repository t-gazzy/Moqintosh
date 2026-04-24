//
//  CallApplicationPresentationState.swift
//  CallApplicationSample
//
//  Created by Codex on 2026/04/22.
//

import Foundation

struct CallApplicationPresentationState {
    enum DeliveryMode: String {
        case stream
        case datagram
    }

    enum TrackKind: String, CaseIterable, Identifiable {
        case video
        case audio
        case data

        var id: String {
            rawValue
        }
    }

    struct NamespaceItem: Identifiable {
        let id: UUID
        let displayName: String
    }

    struct PublishedTrackItem: Identifiable {
        let id: UInt64
        let namespaceID: UUID
        let displayName: String
        let forwardDescription: String
        let kind: TrackKind
    }

    struct InboundSubscriptionItem: Identifiable {
        let id: UInt64
        let displayName: String
        let forwardDescription: String
        let kind: TrackKind
        let matchingPublishedTrackID: UInt64
        let canStartDelivery: Bool
        let selectedMode: DeliveryMode?
    }

    struct RemoteTrackItem: Identifiable {
        let id: UInt64
        let displayName: String
        let kind: TrackKind
    }

    struct RemoteVideoItem: Identifiable {
        let id: UInt64
        let displayName: String
    }

    struct ActiveFetchItem: Identifiable {
        let id: UInt64
        let displayName: String
        let kind: TrackKind
    }

    var isConnected: Bool
    var isConnecting: Bool
    var connectionErrorMessage: String?
    var connectedEndpointDescription: String
    var activePublishedNamespaces: [NamespaceItem]
    var activeSubscribedNamespaces: [NamespaceItem]
    var localPublishedTracks: [PublishedTrackItem]
    var inboundSubscriptionRequests: [InboundSubscriptionItem]
    var remoteTracks: [RemoteTrackItem]
    var remoteVideoTracks: [RemoteVideoItem]
    var activeFetchSubscriptions: [ActiveFetchItem]
    var dataLogLines: [String]
    var eventLogLines: [String]

    init() {
        self.isConnected = false
        self.isConnecting = false
        self.connectionErrorMessage = nil
        self.connectedEndpointDescription = "Disconnected"
        self.activePublishedNamespaces = []
        self.activeSubscribedNamespaces = []
        self.localPublishedTracks = []
        self.inboundSubscriptionRequests = []
        self.remoteTracks = []
        self.remoteVideoTracks = []
        self.activeFetchSubscriptions = []
        self.dataLogLines = []
        self.eventLogLines = []
    }
}
