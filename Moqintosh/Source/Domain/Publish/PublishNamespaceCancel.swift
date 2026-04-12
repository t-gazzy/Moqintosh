//
//  PublishNamespaceCancel.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

/// Represents a `PUBLISH_NAMESPACE_CANCEL` received from the peer.
public struct PublishNamespaceCancel {

    /// The cancelled namespace prefix.
    public let trackNamespace: TrackNamespace
    /// The error code reported by the peer.
    public let errorCode: UInt64
    /// The reason phrase reported by the peer.
    public let reasonPhrase: String

    /// Creates a namespace cancellation value.
    public init(trackNamespace: TrackNamespace, errorCode: UInt64, reasonPhrase: String) {
        self.trackNamespace = trackNamespace
        self.errorCode = errorCode
        self.reasonPhrase = reasonPhrase
    }
}
