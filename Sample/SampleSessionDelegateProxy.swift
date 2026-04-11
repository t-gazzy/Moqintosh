//
//  SampleSessionDelegateProxy.swift
//  Sample
//
//  Created by Codex on 2026/04/11.
//

import Foundation
import Moqintosh

final class SampleSessionDelegateProxy: SessionDelegate {

    private let stateQueue: DispatchQueue
    private let configuration: SampleConfiguration
    private let onEvent: @Sendable (String) -> Void
    private let onRemotePublishedNamespace: @Sendable (TrackNamespace) -> Void
    private let onIncomingSubscribe: @Sendable (PublishedTrack) -> Void
    private var advertisedNamespaces: [TrackNamespace]

    init(
        configuration: SampleConfiguration,
        onEvent: @escaping @Sendable (String) -> Void,
        onRemotePublishedNamespace: @escaping @Sendable (TrackNamespace) -> Void,
        onIncomingSubscribe: @escaping @Sendable (PublishedTrack) -> Void
    ) {
        self.stateQueue = .init(label: "Sample.SessionDelegateProxy")
        self.configuration = configuration
        self.onEvent = onEvent
        self.onRemotePublishedNamespace = onRemotePublishedNamespace
        self.onIncomingSubscribe = onIncomingSubscribe
        self.advertisedNamespaces = []
    }

    func registerAdvertisedNamespace(_ namespace: TrackNamespace) {
        stateQueue.sync {
            advertisedNamespaces.removeAll { $0.elements == namespace.elements }
            advertisedNamespaces.append(namespace)
        }
    }

    func session(
        _ session: Session,
        shouldAcceptSubscribeNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) -> Bool {
        true
    }

    func session(
        _ session: Session,
        didReceiveSubscribeNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) {
        onEvent("Peer requested namespace subscription: \(configuration.makeNamespaceString(from: prefix))")
    }

    func session(_ session: Session, didReceiveSubscribe publishedTrack: PublishedTrack) -> Bool {
        let isAccepted: Bool = stateQueue.sync {
            advertisedNamespaces.contains { namespace in
                namespace.elements == publishedTrack.resource.trackNamespace.elements
            }
        }
        onEvent("Peer requested subscribe: \(describe(resource: publishedTrack.resource))")
        if isAccepted {
            onEvent("Peer subscribe accepted")
            onIncomingSubscribe(publishedTrack)
        }
        return isAccepted
    }

    func session(
        _ session: Session,
        shouldAcceptPublishNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) -> Bool {
        true
    }

    func session(
        _ session: Session,
        didReceivePublishNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) {
        onRemotePublishedNamespace(prefix)
        onEvent("Peer published namespace: \(configuration.makeNamespaceString(from: prefix))")
    }

    func session(_ session: Session, didReceivePublish resource: TrackResource) -> Bool {
        onEvent("Peer published track: \(describe(resource: resource))")
        return true
    }

    private func describe(resource: TrackResource) -> String {
        let namespaceText: String = configuration.makeNamespaceString(from: resource.trackNamespace)
        let trackNameText: String = String(data: resource.trackName, encoding: .utf8) ?? "<binary>"
        return "\(namespaceText)/\(trackNameText)"
    }
}
