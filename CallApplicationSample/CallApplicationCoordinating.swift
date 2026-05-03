//
//  CallApplicationCoordinating.swift
//  CallApplicationSample
//
//  Created by Codex on 2026/04/22.
//

import Foundation

#if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
import RealtimeMediaKit
#endif

@MainActor
protocol CallApplicationCoordinatorDelegate: AnyObject {
    func coordinator(
        _ coordinator: any CallApplicationCoordinating,
        didUpdate state: CallApplicationPresentationState
    )
}

@MainActor
protocol CallApplicationCoordinating: AnyObject {
    var delegate: (any CallApplicationCoordinatorDelegate)? { get set }

    func connect(endpointAddress: String, allowsUntrustedCertificates: Bool) async
    func publishNamespace(input: String) async
    func subscribeNamespace(input: String) async
    func publishTrack(
        selectedNamespaceID: UUID?,
        trackKind: CallApplicationPresentationState.TrackKind,
        forward: Bool
    ) async
    func startSending(
        requestID: UInt64,
        mode: CallApplicationPresentationState.DeliveryMode
    ) async
    func publishDone(requestID: UInt64) async
    func publishNamespaceDone(namespaceID: UUID) async
    func unsubscribeNamespace(namespaceID: UUID) async
    func unsubscribeRemoteTrack(requestID: UInt64) async
    func fetchRemoteTrack(
        selectedTrackID: UInt64?,
        startObjectText: String,
        endObjectText: String
    ) async
    func cancelFetch(requestID: UInt64) async
    func sendGoAway() async

    #if os(iOS) || os(tvOS) || os(visionOS) || targetEnvironment(macCatalyst)
    func videoRenderView(for remoteTrackID: UInt64?) -> VideoRenderView?
    #endif
}
