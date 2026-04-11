//
//  TrackNamespaceTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct TrackNamespaceTests {

    @Test func roundTrip() throws {
        let namespace: TrackNamespace = TrackNamespace(strings: ["live", "video"])
        let decoded: TrackNamespace = try .decode(from: ByteReader(data: namespace.encode()))
        #expect(decoded.elements == namespace.elements)
    }

    @Test func invalidElementCount() throws {
        let reader: ByteReader = ByteReader(data: Data([0x00]))
        #expect(throws: TrackNamespaceError.self) {
            try TrackNamespace.decode(from: reader)
        }
    }
}
