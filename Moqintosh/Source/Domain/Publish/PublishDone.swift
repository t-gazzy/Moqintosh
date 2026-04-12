//
//  PublishDone.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

/// The terminal status of a published track.
public struct PublishDone {

    /// The request identifier of the finished publish.
    public let requestID: UInt64
    /// The status code reported by the publisher.
    public let statusCode: UInt64
    /// The number of streams used to deliver the publish.
    public let streamCount: UInt64
    /// The accompanying reason phrase.
    public let reasonPhrase: String

    /// Creates a publish-done event value.
    public init(requestID: UInt64, statusCode: UInt64, streamCount: UInt64, reasonPhrase: String) {
        self.requestID = requestID
        self.statusCode = statusCode
        self.streamCount = streamCount
        self.reasonPhrase = reasonPhrase
    }
}
