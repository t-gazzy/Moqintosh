//
//  MOQTMessage.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// A decoded MOQT control message.
enum MOQTMessage {
    case clientSetup(ClientSetupMessage)
    case serverSetup(ServerSetupMessage)
    case goaway(GoAwayMessage)
    case maxRequestID(MaxRequestIDMessage)
    case requestsBlocked(RequestsBlockedMessage)
    case subscribe(SubscribeMessage)
    case subscribeOK(SubscribeOKMessage)
    case subscribeError(SubscribeErrorMessage)
    case subscribeUpdate(SubscribeUpdateMessage)
    case unsubscribe(UnsubscribeMessage)
    case fetch(FetchMessage)
    case fetchOK(FetchOKMessage)
    case fetchError(FetchErrorMessage)
    case fetchCancel(FetchCancelMessage)
    case trackStatus(TrackStatusMessage)
    case trackStatusOK(TrackStatusOKMessage)
    case trackStatusError(TrackStatusErrorMessage)
    case publish(PublishMessage)
    case publishOK(PublishOKMessage)
    case publishError(PublishErrorMessage)
    case publishDone(PublishDoneMessage)
    case publishNamespace(PublishNamespaceMessage)
    case publishNamespaceOK(PublishNamespaceOKMessage)
    case publishNamespaceError(PublishNamespaceErrorMessage)
    case publishNamespaceDone(PublishNamespaceDoneMessage)
    case publishNamespaceCancel(PublishNamespaceCancelMessage)
    case subscribeNamespace(SubscribeNamespaceMessage)
    case subscribeNamespaceOK(SubscribeNamespaceOKMessage)
    case subscribeNamespaceError(SubscribeNamespaceErrorMessage)
    case unsubscribeNamespace(UnsubscribeNamespaceMessage)
    /// A recognized message type that is not yet implemented.
    case unknown(type: UInt64, payload: Data)
}
