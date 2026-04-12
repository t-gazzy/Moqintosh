//
//  PublishDone.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

public struct PublishDone {

    public let requestID: UInt64
    public let statusCode: UInt64
    public let streamCount: UInt64
    public let reasonPhrase: String

    public init(requestID: UInt64, statusCode: UInt64, streamCount: UInt64, reasonPhrase: String) {
        self.requestID = requestID
        self.statusCode = statusCode
        self.streamCount = streamCount
        self.reasonPhrase = reasonPhrase
    }
}
