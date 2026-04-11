//
//  ControlMessageParameterTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct ControlMessageParameterTests {

    @Test func roundTrip() throws {
        let parameters: [ControlMessageParameter] = [
            .authorizationToken(.init(value: Data([0x01, 0x02]))),
            .deliveryTimeout(10),
            .maxCacheDuration(20)
        ]

        for parameter in parameters {
            let decoded: ControlMessageParameter = try .decode(from: .init(data: parameter.encode()))

            switch (parameter, decoded) {
            case (.authorizationToken(let lhs), .authorizationToken(let rhs)):
                #expect(lhs.value == rhs.value)
            case (.deliveryTimeout(let lhs), .deliveryTimeout(let rhs)):
                #expect(lhs == rhs)
            case (.maxCacheDuration(let lhs), .maxCacheDuration(let rhs)):
                #expect(lhs == rhs)
            default:
                Issue.record("Decoded parameter did not match original")
            }
        }
    }
}
