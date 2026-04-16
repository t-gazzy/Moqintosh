//
//  ControlMessageDispatcher.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

actor ControlMessageDispatcher {

    private let sessionContext: SessionContext

    init(sessionContext: SessionContext) {
        self.sessionContext = sessionContext
    }

    func handle(_ message: MOQTMessage) async {
        switch message {
        case .goaway(let goAwayMessage):
            await handleIncomingGoAway(goAwayMessage)
        case .maxRequestID(let maxRequestIDMessage):
            handleIncomingMaxRequestID(maxRequestIDMessage)
        case .requestsBlocked(let requestsBlockedMessage):
            handleIncomingRequestsBlocked(requestsBlockedMessage)
        case .publish(let publishMessage):
            await handleIncomingPublish(publishMessage)
        case .publishOK(let publishOKMessage):
            sessionContext.requestStore.resolvePublishRequest(with: publishOKMessage)
        case .publishError(let publishErrorMessage):
            sessionContext.requestStore.rejectPublishRequest(with: publishErrorMessage)
        case .publishDone(let publishDoneMessage):
            await handleIncomingPublishDone(publishDoneMessage)
        case .publishNamespace(let publishNamespaceMessage):
            await handleIncomingPublishNamespace(publishNamespaceMessage)
        case .publishNamespaceOK(let publishNamespaceOKMessage):
            sessionContext.requestStore.resolveRequest(with: publishNamespaceOKMessage)
        case .publishNamespaceError(let publishNamespaceErrorMessage):
            sessionContext.requestStore.rejectRequest(with: publishNamespaceErrorMessage)
        case .publishNamespaceDone(let publishNamespaceDoneMessage):
            await handleIncomingPublishNamespaceDone(publishNamespaceDoneMessage)
        case .publishNamespaceCancel(let publishNamespaceCancelMessage):
            await handleIncomingPublishNamespaceCancel(publishNamespaceCancelMessage)
        case .subscribe(let subscribeMessage):
            await handleIncomingSubscribe(subscribeMessage)
        case .subscribeOK(let subscribeOKMessage):
            sessionContext.requestStore.resolveSubscribeRequest(with: subscribeOKMessage)
        case .subscribeError(let subscribeErrorMessage):
            sessionContext.requestStore.rejectSubscribeRequest(with: subscribeErrorMessage)
        case .subscribeUpdate(let subscribeUpdateMessage):
            await handleIncomingSubscribeUpdate(subscribeUpdateMessage)
        case .unsubscribe(let unsubscribeMessage):
            await handleIncomingUnsubscribe(unsubscribeMessage)
        case .trackStatusOK(let trackStatusOKMessage):
            sessionContext.requestStore.resolveTrackStatusRequest(with: trackStatusOKMessage)
        case .trackStatusError(let trackStatusErrorMessage):
            sessionContext.requestStore.rejectTrackStatusRequest(with: trackStatusErrorMessage)
        case .fetch(let fetchMessage):
            await handleIncomingFetch(fetchMessage)
        case .fetchOK(let fetchOKMessage):
            sessionContext.requestStore.resolveFetchRequest(with: fetchOKMessage)
        case .fetchError(let fetchErrorMessage):
            sessionContext.requestStore.rejectFetchRequest(with: fetchErrorMessage)
        case .fetchCancel(let fetchCancelMessage):
            await handleIncomingFetchCancel(fetchCancelMessage)
        case .trackStatus(let trackStatusMessage):
            await handleIncomingTrackStatus(trackStatusMessage)
        case .subscribeNamespace(let subscribeNamespaceMessage):
            await handleIncomingSubscribeNamespace(subscribeNamespaceMessage)
        case .subscribeNamespaceOK(let subscribeNamespaceOKMessage):
            sessionContext.requestStore.resolveRequest(with: subscribeNamespaceOKMessage)
        case .subscribeNamespaceError(let subscribeNamespaceErrorMessage):
            sessionContext.requestStore.rejectRequest(with: subscribeNamespaceErrorMessage)
        case .unsubscribeNamespace(let unsubscribeNamespaceMessage):
            await handleIncomingUnsubscribeNamespace(unsubscribeNamespaceMessage)
        default:
            OSLogger.debug("Unhandled message: \(message)")
        }
    }

    private func handleIncomingGoAway(_ message: GoAwayMessage) async {
        guard let session: Session = sessionContext.session else { return }
        await session.didReceiveGoAway(newSessionURI: message.newSessionURI)
    }

    private func handleIncomingMaxRequestID(_ message: MaxRequestIDMessage) {
        OSLogger.debug("Received MAX_REQUEST_ID (requestID: \(message.requestID))")
        sessionContext.updateRemoteMaxRequestID(message.requestID)
    }

    private func handleIncomingRequestsBlocked(_ message: RequestsBlockedMessage) {
        OSLogger.debug("Received REQUESTS_BLOCKED (requestID: \(message.requestID))")
    }

    private func handleIncomingPublishNamespace(_ message: PublishNamespaceMessage) async {
        guard let session: Session = sessionContext.session else { return }
        let decision: PublishNamespaceDecision = await session.didReceivePublishNamespace(
            prefix: message.trackNamespace,
            authorizationToken: message.authorizationTokens.first
        )
        let response: Data
        switch decision {
        case .accept:
            response = PublishNamespaceOKMessage(requestID: message.requestID).encode()
        case .reject(let error):
            response = PublishNamespaceErrorMessage(
                requestID: message.requestID,
                errorCode: error.code.rawValue,
                reasonPhrase: error.reason
            ).encode()
        }
        try? await sessionContext.controlStream.send(bytes: response)
    }

    private func handleIncomingPublish(_ message: PublishMessage) async {
        guard let session: Session = sessionContext.session else { return }
        let decision: PublishDecision = await session.didReceivePublish(resource: message.publishedTrack.resource)
        let response: Data
        switch decision {
        case .accept(let acceptance):
            response = PublishOKMessage(
                requestID: message.requestID,
                forward: acceptance.forward,
                subscriberPriority: acceptance.subscriberPriority,
                groupOrder: acceptance.groupOrder,
                filter: acceptance.filter,
                deliveryTimeout: acceptance.deliveryTimeout
            ).encode()
        case .reject(let error):
            response = PublishErrorMessage(
                requestID: message.requestID,
                errorCode: error.code.rawValue,
                reasonPhrase: error.reason
            ).encode()
        }
        try? await sessionContext.controlStream.send(bytes: response)
    }

    private func handleIncomingSubscribe(_ message: SubscribeMessage) async {
        guard let session: Session = sessionContext.session else { return }
        let groupOrder: GroupOrder = message.groupOrder == .publisherDefault ? .ascending : message.groupOrder
        let publishedTrack: PublishedTrack = PublishedTrack(
            requestID: message.requestID,
            resource: message.resource,
            trackAlias: sessionContext.issueTrackAlias(),
            groupOrder: groupOrder,
            contentExist: .noContent,
            forward: message.forward
        )
        let decision: SubscribeDecision = await session.didReceiveSubscribe(publishedTrack: publishedTrack)
        let response: Data
        switch decision {
        case .accept(let acceptance):
            sessionContext.registerInboundSubscriptionResource(
                requestID: message.requestID,
                resource: message.resource
            )
            response = SubscribeOKMessage(
                requestID: message.requestID,
                trackAlias: acceptance.publishedTrack.trackAlias,
                expires: acceptance.expires,
                groupOrder: acceptance.publishedTrack.groupOrder,
                contentExist: acceptance.publishedTrack.contentExist,
                deliveryTimeout: acceptance.deliveryTimeout,
                maxCacheDuration: acceptance.maxCacheDuration
            ).encode()
        case .reject(let error):
            response = SubscribeErrorMessage(
                requestID: message.requestID,
                errorCode: error.code.rawValue,
                reasonPhrase: error.reason
            ).encode()
        }
        try? await sessionContext.controlStream.send(bytes: response)
    }

    private func handleIncomingSubscribeNamespace(_ message: SubscribeNamespaceMessage) async {
        guard let session: Session = sessionContext.session else { return }
        let decision: SubscribeNamespaceDecision = await session.didReceiveSubscribeNamespace(
            prefix: message.namespacePrefix,
            authorizationToken: message.authorizationTokens.first
        )
        let response: Data
        switch decision {
        case .accept:
            response = SubscribeNamespaceOKMessage(requestID: message.requestID).encode()
        case .reject(let error):
            response = SubscribeNamespaceErrorMessage(
                requestID: message.requestID,
                errorCode: error.code.rawValue,
                reasonPhrase: error.reason
            ).encode()
        }
        try? await sessionContext.controlStream.send(bytes: response)
    }

    private func handleIncomingSubscribeUpdate(_ message: SubscribeUpdateMessage) async {
        guard let session: Session = sessionContext.session else { return }
        let update: SubscribeUpdate = SubscribeUpdate(
            requestID: message.requestID,
            start: message.start,
            endGroup: message.endGroup,
            subscriberPriority: message.subscriberPriority,
            forward: message.forward,
            authorizationToken: message.authorizationToken
        )
        await session.didReceiveSubscribeUpdate(update)
    }

    private func handleIncomingUnsubscribe(_ message: UnsubscribeMessage) async {
        guard let session: Session = sessionContext.session else { return }
        sessionContext.removeInboundSubscriptionResource(requestID: message.requestID)
        await session.didReceiveUnsubscribe(requestID: message.requestID)
    }

    private func handleIncomingFetch(_ message: FetchMessage) async {
        guard let session: Session = sessionContext.session else { return }
        let request: FetchRequest
        switch message.mode {
        case .standalone(let resource, let start, let end):
            request = .standalone(
                requestID: message.requestID,
                resource: resource,
                subscriberPriority: message.subscriberPriority,
                groupOrder: message.groupOrder,
                start: start,
                end: end
            )
        case .joiningRelative(let joiningRequestID, let startGroupOffset):
            guard let resource: TrackResource = sessionContext.inboundSubscriptionResource(for: joiningRequestID) else {
                let response: Data = FetchErrorMessage(
                    requestID: message.requestID,
                    errorCode: 0x7,
                    reasonPhrase: "Invalid joining request ID"
                ).encode()
                try? await sessionContext.controlStream.send(bytes: response)
                return
            }
            request = .joiningRelative(
                requestID: message.requestID,
                joiningRequestID: joiningRequestID,
                resource: resource,
                subscriberPriority: message.subscriberPriority,
                groupOrder: message.groupOrder,
                startGroupOffset: startGroupOffset
            )
        case .joiningAbsolute(let joiningRequestID, let startGroup):
            guard let resource: TrackResource = sessionContext.inboundSubscriptionResource(for: joiningRequestID) else {
                let response: Data = FetchErrorMessage(
                    requestID: message.requestID,
                    errorCode: 0x7,
                    reasonPhrase: "Invalid joining request ID"
                ).encode()
                try? await sessionContext.controlStream.send(bytes: response)
                return
            }
            request = .joiningAbsolute(
                requestID: message.requestID,
                joiningRequestID: joiningRequestID,
                resource: resource,
                subscriberPriority: message.subscriberPriority,
                groupOrder: message.groupOrder,
                startGroup: startGroup
            )
        }
        let decision: FetchDecision = await session.fetchDecision(for: request)
        let response: Data
        switch decision {
        case .accept(let fetchResponse):
            response = FetchOKMessage(
                requestID: message.requestID,
                groupOrder: fetchResponse.groupOrder,
                endOfTrack: fetchResponse.endOfTrack,
                endLocation: fetchResponse.endLocation,
                maxCacheDuration: fetchResponse.maxCacheDuration
            ).encode()
        case .reject(let error):
            response = FetchErrorMessage(
                requestID: message.requestID,
                errorCode: error.code.rawValue,
                reasonPhrase: error.reason
            ).encode()
        }
        try? await sessionContext.controlStream.send(bytes: response)
    }

    private func handleIncomingFetchCancel(_ message: FetchCancelMessage) async {
        guard let session: Session = sessionContext.session else { return }
        await session.didReceiveFetchCancel(requestID: message.requestID)
    }

    private func handleIncomingTrackStatus(_ message: TrackStatusMessage) async {
        guard let session: Session = sessionContext.session else { return }
        let request: TrackStatusRequest = TrackStatusRequest(
            requestID: message.requestID,
            resource: message.resource,
            subscriberPriority: message.subscriberPriority,
            groupOrder: message.groupOrder,
            forward: message.forward,
            filter: message.filter
        )
        let decision: TrackStatusDecision = await session.trackStatusDecision(for: request)
        let response: Data
        switch decision {
        case .accept(let trackStatus):
            response = TrackStatusOKMessage(requestID: message.requestID, trackStatus: trackStatus).encode()
        case .reject(let error):
            response = TrackStatusErrorMessage(
                requestID: message.requestID,
                errorCode: error.code.rawValue,
                reasonPhrase: error.reason
            ).encode()
        }
        try? await sessionContext.controlStream.send(bytes: response)
    }

    private func handleIncomingPublishDone(_ message: PublishDoneMessage) async {
        guard let session: Session = sessionContext.session else { return }
        let publishDone: PublishDone = PublishDone(
            requestID: message.requestID,
            statusCode: message.statusCode,
            streamCount: message.streamCount,
            reasonPhrase: message.reasonPhrase
        )
        await session.didReceivePublishDone(publishDone)
    }

    private func handleIncomingPublishNamespaceDone(_ message: PublishNamespaceDoneMessage) async {
        guard let session: Session = sessionContext.session else { return }
        await session.didReceivePublishNamespaceDone(trackNamespace: message.trackNamespace)
    }

    private func handleIncomingPublishNamespaceCancel(_ message: PublishNamespaceCancelMessage) async {
        guard let session: Session = sessionContext.session else { return }
        let cancellation: PublishNamespaceCancel = PublishNamespaceCancel(
            trackNamespace: message.trackNamespace,
            errorCode: message.errorCode,
            reasonPhrase: message.reasonPhrase
        )
        await session.didReceivePublishNamespaceCancel(cancellation)
    }

    private func handleIncomingUnsubscribeNamespace(_ message: UnsubscribeNamespaceMessage) async {
        guard let session: Session = sessionContext.session else { return }
        await session.didReceiveUnsubscribeNamespace(namespacePrefix: message.namespacePrefix)
    }

}
