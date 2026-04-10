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
    /// A recognized message type that is not yet implemented.
    case unknown(type: UInt64, payload: Data)
}
