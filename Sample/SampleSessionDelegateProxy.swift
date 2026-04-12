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
        self.stateQueue = DispatchQueue(label: "Sample.SessionDelegateProxy")
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
        didReceiveSubscribeNamespace prefix: TrackNamespace,
        authorizationToken: AuthorizationToken?
    ) -> SubscribeNamespaceDecision {
        onEvent("Peer requested namespace subscription: \(configuration.makeNamespaceString(from: prefix))")
        return .accept
    }

    func session(_ session: Session, didReceiveSubscribe publishedTrack: PublishedTrack) -> SubscribeDecision {
        let isAccepted: Bool = stateQueue.sync {
            advertisedNamespaces.contains { namespace in
                namespace.elements == publishedTrack.resource.trackNamespace.elements
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
    ) -> PublishNamespaceDecision {
        onRemotePublishedNamespace(prefix)
        onEvent("Peer published namespace: \(configuration.makeNamespaceString(from: prefix))")
        return .accept
    }

    func session(_ session: Session, didReceivePublish resource: TrackResource) -> PublishDecision {
        onEvent("Peer published track: \(describe(resource: resource))")
        return .accept(PublishAcceptance())
    }

    private func describe(resource: TrackResource) -> String {
        let namespaceText: String = configuration.makeNamespaceString(from: resource.trackNamespace)
        let trackNameText: String = String(data: resource.trackName, encoding: .utf8) ?? "<binary>"
        return "\(namespaceText)/\(trackNameText)"
    }
}
