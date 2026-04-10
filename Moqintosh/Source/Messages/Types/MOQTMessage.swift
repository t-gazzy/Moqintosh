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
    case subscribe(SubscribeMessage)
    case subscribeOK(SubscribeOKMessage)
    case subscribeError(SubscribeErrorMessage)
    case subscribeUpdate
    case unsubscribe
    case fetch
    case fetchCancel
    case trackStatus
    case publish(PublishMessage)
    case publishOK(PublishOKMessage)
    case publishError(PublishErrorMessage)
    case publishDone
    case publishNamespace(PublishNamespaceMessage)
    case publishNamespaceOK(PublishNamespaceOKMessage)
    case publishNamespaceError(PublishNamespaceErrorMessage)
    case publishNamespaceDone
    case subscribeNamespace(SubscribeNamespaceMessage)
    case subscribeNamespaceOK(SubscribeNamespaceOKMessage)
    case subscribeNamespaceError(SubscribeNamespaceErrorMessage)
    /// A recognized message type that is not yet implemented.
    case unknown(type: UInt64, payload: Data)
}
