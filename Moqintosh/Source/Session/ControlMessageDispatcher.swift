//
//  ControlMessageDispatcher.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

final class ControlMessageDispatcher {

    private let sessionContext: SessionContext

    init(sessionContext: SessionContext) {
        self.sessionContext = sessionContext
    }

    func handle(_ message: MOQTMessage) async {
        switch message {
        case .publish(let publishMessage):
            await handleIncomingPublish(publishMessage)
        case .publishOK(let publishOKMessage):
            sessionContext.requestStore.resolvePublishRequest(with: publishOKMessage)
        case .publishError(let publishErrorMessage):
            sessionContext.requestStore.rejectPublishRequest(with: publishErrorMessage)
        case .publishNamespace(let publishNamespaceMessage):
            await handleIncomingPublishNamespace(publishNamespaceMessage)
        case .publishNamespaceOK(let publishNamespaceOKMessage):
            sessionContext.requestStore.resolveRequest(with: publishNamespaceOKMessage)
        case .publishNamespaceError(let publishNamespaceErrorMessage):
            sessionContext.requestStore.rejectRequest(with: publishNamespaceErrorMessage)
        case .subscribe(let subscribeMessage):
            await handleIncomingSubscribe(subscribeMessage)
        case .subscribeOK(let subscribeOKMessage):
            sessionContext.requestStore.resolveSubscribeRequest(with: subscribeOKMessage)
        case .subscribeError(let subscribeErrorMessage):
            sessionContext.requestStore.rejectSubscribeRequest(with: subscribeErrorMessage)
        case .subscribeNamespace(let subscribeNamespaceMessage):
            await handleIncomingSubscribeNamespace(subscribeNamespaceMessage)
        case .subscribeNamespaceOK(let subscribeNamespaceOKMessage):
            sessionContext.requestStore.resolveRequest(with: subscribeNamespaceOKMessage)
        case .subscribeNamespaceError(let subscribeNamespaceErrorMessage):
            sessionContext.requestStore.rejectRequest(with: subscribeNamespaceErrorMessage)
        default:
            OSLogger.debug("Unhandled message: \(message)")
        }
    }

    private func handleIncomingPublishNamespace(_ message: PublishNamespaceMessage) async {
        guard let session: Session = sessionContext.session else { return }
        let isAccepted: Bool = session.shouldAcceptPublishNamespace(
            prefix: message.trackNamespace,
            authorizationToken: message.authorizationTokens.first
        )
        let response: Data = isAccepted
            ? PublishNamespaceOKMessage(requestID: message.requestID).encode()
            : PublishNamespaceErrorMessage(
                requestID: message.requestID,
                errorCode: 0x1,
                reasonPhrase: "Rejected"
            ).encode()
        try? await sessionContext.controlStream.send(bytes: response)
    }

    private func handleIncomingPublish(_ message: PublishMessage) async {
        guard let session: Session = sessionContext.session else { return }
        let isAccepted: Bool = session.shouldAcceptPublish(resource: message.publishedTrack.resource)
        let response: Data = isAccepted
            ? PublishOKMessage(
                requestID: message.requestID,
                forward: message.publishedTrack.forward,
                subscriberPriority: 0,
                groupOrder: message.publishedTrack.groupOrder,
                filter: .largestObject,
                deliveryTimeout: message.deliveryTimeout
            ).encode()
            : PublishErrorMessage(
                requestID: message.requestID,
                errorCode: 0x04,
                reasonPhrase: "Rejected"
            ).encode()
        try? await sessionContext.controlStream.send(bytes: response)
    }

    private func handleIncomingSubscribe(_ message: SubscribeMessage) async {
        guard let session: Session = sessionContext.session else { return }
        let groupOrder: GroupOrder = message.groupOrder == .publisherDefault ? .ascending : message.groupOrder
        let publishedTrack: PublishedTrack = .init(
            requestID: message.requestID,
            resource: message.resource,
            trackAlias: sessionContext.issueTrackAlias(),
            groupOrder: groupOrder,
            contentExist: .noContent,
            forward: message.forward
        )
        let isAccepted: Bool = session.shouldAcceptSubscribe(publishedTrack: publishedTrack)
        let response: Data = isAccepted
            ? SubscribeOKMessage(
                requestID: message.requestID,
                trackAlias: publishedTrack.trackAlias,
                expires: 0,
                groupOrder: groupOrder,
                contentExist: .noContent,
                deliveryTimeout: message.deliveryTimeout,
                maxCacheDuration: nil
            ).encode()
            : SubscribeErrorMessage(
                requestID: message.requestID,
                errorCode: 0x01,
                reasonPhrase: "Rejected"
            ).encode()
        try? await sessionContext.controlStream.send(bytes: response)
    }

    private func handleIncomingSubscribeNamespace(_ message: SubscribeNamespaceMessage) async {
        guard let session: Session = sessionContext.session else { return }
        let isAccepted: Bool = session.shouldAcceptSubscribeNamespace(
            prefix: message.namespacePrefix,
            authorizationToken: message.authorizationTokens.first
        )
        let response: Data = isAccepted
            ? SubscribeNamespaceOKMessage(requestID: message.requestID).encode()
            : SubscribeNamespaceErrorMessage(
                requestID: message.requestID,
                errorCode: 0x1,
                reasonPhrase: "Rejected"
            ).encode()
        try? await sessionContext.controlStream.send(bytes: response)
    }

}
