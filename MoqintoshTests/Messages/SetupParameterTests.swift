//
//  SetupParameterTests.swift
//  MoqintoshTests
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct SetupParameterTests {

    @Test func roundTrip() throws {
        let parameters: [SetupParameter] = [
            .path("/live"),
            .maxRequestId(128),
            .maxAuthTokenCacheSize(32),
            .authorizationToken(.init(value: Data([0xAA, 0xBB]))),
            .authority("example.com"),
            .moqtImplementation("Moqintosh")
        ]

        for parameter in parameters {
            let decoded: SetupParameter = try .decode(from: .init(data: parameter.encode()))

            switch (parameter, decoded) {
            case (.path(let lhs), .path(let rhs)):
                #expect(lhs == rhs)
            case (.maxRequestId(let lhs), .maxRequestId(let rhs)):
                #expect(lhs == rhs)
            case (.maxAuthTokenCacheSize(let lhs), .maxAuthTokenCacheSize(let rhs)):
                #expect(lhs == rhs)
            case (.authorizationToken(let lhs), .authorizationToken(let rhs)):
                #expect(lhs.value == rhs.value)
            case (.authority(let lhs), .authority(let rhs)):
                #expect(lhs == rhs)
            case (.moqtImplementation(let lhs), .moqtImplementation(let rhs)):
                #expect(lhs == rhs)
            default:
                Issue.record("Decoded parameter did not match original")
            }
        }
    }
}
