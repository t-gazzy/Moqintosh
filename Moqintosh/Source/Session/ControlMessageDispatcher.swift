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
            sessionContext.resolvePublishRequest(with: publishOKMessage)
        case .publishError(let publishErrorMessage):
            sessionContext.rejectPublishRequest(with: publishErrorMessage)
        case .publishNamespace(let publishNamespaceMessage):
            await handleIncomingPublishNamespace(publishNamespaceMessage)
        case .publishNamespaceOK(let publishNamespaceOKMessage):
            sessionContext.resolveRequest(with: publishNamespaceOKMessage)
        case .publishNamespaceError(let publishNamespaceErrorMessage):
            sessionContext.rejectRequest(with: publishNamespaceErrorMessage)
        case .subscribe(let subscribeMessage):
            await handleIncomingSubscribe(subscribeMessage)
        case .subscribeOK(let subscribeOKMessage):
            sessionContext.resolveSubscribeRequest(with: subscribeOKMessage)
        case .subscribeError(let subscribeErrorMessage):
            sessionContext.rejectSubscribeRequest(with: subscribeErrorMessage)
        case .subscribeNamespace(let subscribeNamespaceMessage):
            await handleIncomingSubscribeNamespace(subscribeNamespaceMessage)
        case .subscribeNamespaceOK(let subscribeNamespaceOKMessage):
            sessionContext.resolveRequest(with: subscribeNamespaceOKMessage)
        case .subscribeNamespaceError(let subscribeNamespaceErrorMessage):
            sessionContext.rejectRequest(with: subscribeNamespaceErrorMessage)
        default:
            OSLogger.debug("Unhandled message: \(message)")
        }
    }

    private func handleIncomingPublishNamespace(_ message: PublishNamespaceMessage) async {
        guard let session: Session = sessionContext.session else { return }
        let authorizationToken: AuthorizationToken? = firstAuthorizationToken(in: message.parameters)
        let isAccepted: Bool = session.delegate?.session(
            session,
            shouldAcceptPublishNamespace: message.trackNamespace,
            authorizationToken: authorizationToken
        ) ?? false
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
        let isAccepted: Bool = session.delegate?.session(session, didReceivePublish: message.publishedTrack.resource) ?? false
        let response: Data = isAccepted
            ? PublishOKMessage(
                requestID: message.requestID,
                forward: message.publishedTrack.forward,
                subscriberPriority: 0,
                groupOrder: message.publishedTrack.groupOrder,
                filter: .largestObject,
                parameters: []
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
        let isAccepted: Bool = session.delegate?.session(session, didReceiveSubscribe: publishedTrack) ?? false
        let response: Data = isAccepted
            ? SubscribeOKMessage(
                requestID: message.requestID,
                trackAlias: publishedTrack.trackAlias,
                expires: 0,
                groupOrder: groupOrder,
                contentExist: .noContent,
                parameters: []
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
        let authorizationToken: AuthorizationToken? = firstAuthorizationToken(in: message.parameters)
        let isAccepted: Bool = session.delegate?.session(
            session,
            shouldAcceptSubscribeNamespace: message.namespacePrefix,
            authorizationToken: authorizationToken
        ) ?? false
        let response: Data = isAccepted
            ? SubscribeNamespaceOKMessage(requestID: message.requestID).encode()
            : SubscribeNamespaceErrorMessage(
                requestID: message.requestID,
                errorCode: 0x1,
                reasonPhrase: "Rejected"
            ).encode()
        try? await sessionContext.controlStream.send(bytes: response)
    }

    private func firstAuthorizationToken(in parameters: [SetupParameter]) -> AuthorizationToken? {
        for parameter in parameters {
            if case .authorizationToken(let token) = parameter {
                return token
            }
        }
        return nil
    }
}
