//
//  LocationTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Testing
@testable import Moqintosh

struct LocationTests {

    @Test func roundTrip() throws {
        let location: Location = .init(group: 10, object: 20)
        let decoded: Location = try .decode(from: .init(data: location.encode()))
        #expect(decoded.group == 10)
        #expect(decoded.object == 20)
    }
}
