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
        case .goaway(let goAwayMessage):
            handleIncomingGoAway(goAwayMessage)
        case .publish(let publishMessage):
            await handleIncomingPublish(publishMessage)
        case .publishOK(let publishOKMessage):
            sessionContext.requestStore.resolvePublishRequest(with: publishOKMessage)
        case .publishError(let publishErrorMessage):
            sessionContext.requestStore.rejectPublishRequest(with: publishErrorMessage)
        case .publishDone(let publishDoneMessage):
            handleIncomingPublishDone(publishDoneMessage)
        case .publishNamespace(let publishNamespaceMessage):
            await handleIncomingPublishNamespace(publishNamespaceMessage)
        case .publishNamespaceOK(let publishNamespaceOKMessage):
            sessionContext.requestStore.resolveRequest(with: publishNamespaceOKMessage)
        case .publishNamespaceError(let publishNamespaceErrorMessage):
            sessionContext.requestStore.rejectRequest(with: publishNamespaceErrorMessage)
        case .publishNamespaceDone(let publishNamespaceDoneMessage):
            handleIncomingPublishNamespaceDone(publishNamespaceDoneMessage)
        case .publishNamespaceCancel(let publishNamespaceCancelMessage):
            handleIncomingPublishNamespaceCancel(publishNamespaceCancelMessage)
        case .subscribe(let subscribeMessage):
            await handleIncomingSubscribe(subscribeMessage)
        case .subscribeOK(let subscribeOKMessage):
            sessionContext.requestStore.resolveSubscribeRequest(with: subscribeOKMessage)
        case .subscribeError(let subscribeErrorMessage):
            sessionContext.requestStore.rejectSubscribeRequest(with: subscribeErrorMessage)
        case .subscribeUpdate(let subscribeUpdateMessage):
            handleIncomingSubscribeUpdate(subscribeUpdateMessage)
        case .unsubscribe(let unsubscribeMessage):
            handleIncomingUnsubscribe(unsubscribeMessage)
        case .trackStatus(let trackStatusMessage):
            await handleIncomingTrackStatus(trackStatusMessage)
        case .trackStatusOK(let trackStatusOKMessage):
            sessionContext.requestStore.resolveTrackStatusRequest(with: trackStatusOKMessage)
        case .trackStatusError(let trackStatusErrorMessage):
            sessionContext.requestStore.rejectTrackStatusRequest(with: trackStatusErrorMessage)
        case .subscribeNamespace(let subscribeNamespaceMessage):
            await handleIncomingSubscribeNamespace(subscribeNamespaceMessage)
        case .subscribeNamespaceOK(let subscribeNamespaceOKMessage):
            sessionContext.requestStore.resolveRequest(with: subscribeNamespaceOKMessage)
        case .subscribeNamespaceError(let subscribeNamespaceErrorMessage):
            sessionContext.requestStore.rejectRequest(with: subscribeNamespaceErrorMessage)
        case .unsubscribeNamespace(let unsubscribeNamespaceMessage):
            handleIncomingUnsubscribeNamespace(unsubscribeNamespaceMessage)
        default:
            OSLogger.debug("Unhandled message: \(message)")
        }
    }

    private func handleIncomingGoAway(_ message: GoAwayMessage) {
        guard let session: Session = sessionContext.session else { return }
        session.didReceiveGoAway(newSessionURI: message.newSessionURI)
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

    private func handleIncomingSubscribeUpdate(_ message: SubscribeUpdateMessage) {
        guard let session: Session = sessionContext.session else { return }
        let update: SubscribeUpdate = .init(
            requestID: message.requestID,
            start: message.start,
            endGroup: message.endGroup,
            subscriberPriority: message.subscriberPriority,
            forward: message.forward,
            authorizationToken: message.authorizationToken
        )
        session.didReceiveSubscribeUpdate(update)
    }

    private func handleIncomingUnsubscribe(_ message: UnsubscribeMessage) {
        guard let session: Session = sessionContext.session else { return }
        session.didReceiveUnsubscribe(requestID: message.requestID)
    }

    private func handleIncomingTrackStatus(_ message: TrackStatusMessage) async {
        guard let session: Session = sessionContext.session else { return }
        let request: TrackStatusRequest = .init(
            requestID: message.requestID,
            resource: message.resource,
            subscriberPriority: message.subscriberPriority,
            groupOrder: message.groupOrder,
            forward: message.forward,
            filter: message.filter
        )
        let response: Data
        do {
            let trackStatus: TrackStatus = try session.trackStatus(for: request)
            response = TrackStatusOKMessage(requestID: message.requestID, trackStatus: trackStatus).encode()
        } catch let error as TrackStatusRequestError {
            switch error {
            case .rejected(let code, let reason):
                response = TrackStatusErrorMessage(
                    requestID: message.requestID,
                    errorCode: code,
                    reasonPhrase: reason
                ).encode()
            }
        } catch {
            response = TrackStatusErrorMessage(
                requestID: message.requestID,
                errorCode: 0x0,
                reasonPhrase: "Rejected"
            ).encode()
        }
        try? await sessionContext.controlStream.send(bytes: response)
    }

    private func handleIncomingPublishDone(_ message: PublishDoneMessage) {
        guard let session: Session = sessionContext.session else { return }
        let publishDone: PublishDone = .init(
            requestID: message.requestID,
            statusCode: message.statusCode,
            streamCount: message.streamCount,
            reasonPhrase: message.reasonPhrase
        )
        session.didReceivePublishDone(publishDone)
    }

    private func handleIncomingPublishNamespaceDone(_ message: PublishNamespaceDoneMessage) {
        guard let session: Session = sessionContext.session else { return }
        session.didReceivePublishNamespaceDone(trackNamespace: message.trackNamespace)
    }

    private func handleIncomingPublishNamespaceCancel(_ message: PublishNamespaceCancelMessage) {
        guard let session: Session = sessionContext.session else { return }
        let cancellation: PublishNamespaceCancel = .init(
            trackNamespace: message.trackNamespace,
            errorCode: message.errorCode,
            reasonPhrase: message.reasonPhrase
        )
        session.didReceivePublishNamespaceCancel(cancellation)
    }

    private func handleIncomingUnsubscribeNamespace(_ message: UnsubscribeNamespaceMessage) {
        guard let session: Session = sessionContext.session else { return }
        session.didReceiveUnsubscribeNamespace(namespacePrefix: message.namespacePrefix)
    }

}
