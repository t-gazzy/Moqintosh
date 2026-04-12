//
//  PublishNamespaceCancel.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

public struct PublishNamespaceCancel {

    public let trackNamespace: TrackNamespace
    public let errorCode: UInt64
    public let reasonPhrase: String

    public init(trackNamespace: TrackNamespace, errorCode: UInt64, reasonPhrase: String) {
        self.trackNamespace = trackNamespace
        self.errorCode = errorCode
        self.reasonPhrase = reasonPhrase
    }
}
