//
//  SampleSessionDelegateProxy.swift
//  Sample
//
//  Created by Codex on 2026/04/11.
//

import Foundation
import Moqintosh
import Synchronization

final class SampleSessionDelegateProxy: SessionDelegate {

    private let advertisedNamespaces: Mutex<[TrackNamespace]>
    private let configuration: SampleConfiguration
    private let onEvent: @Sendable (String) -> Void
    private let onRemotePublishedNamespace: @Sendable (TrackNamespace) -> Void
    private let onIncomingSubscribe: @Sendable (PublishedTrack) -> Void

    init(
        configuration: SampleConfiguration,
        onEvent: @escaping @Sendable (String) -> Void,
        onRemotePublishedNamespace: @escaping @Sendable (TrackNamespace) -> Void,
        onIncomingSubscribe: @escaping @Sendable (PublishedTrack) -> Void
    ) {
        self.advertisedNamespaces = Mutex<[TrackNamespace]>([])
        self.configuration = configuration
        self.onEvent = onEvent
        self.onRemotePublishedNamespace = onRemotePublishedNamespace
        self.onIncomingSubscribe = onIncomingSubscribe
    }

    func registerAdvertisedNamespace(_ namespace: TrackNamespace) {
        advertisedNamespaces.withLock { advertisedNamespaces in
            advertisedNamespaces.removeAll { $0 == namespace }
            advertisedNamespaces.append(namespace)
        }
    }

    func session(
        _ session: Session,
        didReceiveSubscribeNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) async -> SubscribeNamespaceDecision {
        onEvent("Peer requested namespace subscription: \(configuration.makeNamespaceString(from: prefix))")
        return .accept
    }

    func session(_ session: Session, didReceiveSubscribe publishedTrack: PublishedTrack) async -> SubscribeDecision {
        let isAccepted: Bool = advertisedNamespaces.withLock { advertisedNamespaces in
            advertisedNamespaces.contains { namespace in
                namespace == publishedTrack.resource.trackNamespace
            }
        }
        onEvent("Peer requested subscribe: \(describe(resource: publishedTrack.resource))")
        if isAccepted {
            onEvent("Peer subscribe accepted")
            onIncomingSubscribe(publishedTrack)
            return .accept(SubscribeAcceptance(publishedTrack: publishedTrack))
        }
        return .reject(SubscribeRequestError(code: .trackDoesNotExist, reason: "Track does not exist"))
    }

    func session(
        _ session: Session,
        didReceivePublishNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) async -> PublishNamespaceDecision {
        onRemotePublishedNamespace(prefix)
        onEvent("Peer published namespace: \(configuration.makeNamespaceString(from: prefix))")
        return .accept
    }

    func session(_ session: Session, didReceivePublish resource: TrackResource) async -> PublishDecision {
        onEvent("Peer published track: \(describe(resource: resource))")
        return .accept(PublishAcceptance())
    }

    private func describe(resource: TrackResource) -> String {
        let namespaceText: String = configuration.makeNamespaceString(from: resource.trackNamespace)
        let trackNameText: String = String(data: resource.trackName, encoding: .utf8) ?? "<binary>"
        return "\(namespaceText)/\(trackNameText)"
    }
}
