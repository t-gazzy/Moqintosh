//
//  AuthorizationTokenTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct AuthorizationTokenTests {

    @Test func initializerStoresBytes() {
        let token: AuthorizationToken = AuthorizationToken(value: Data([0xCA, 0xFE]))

        #expect(token.value == Data([0xCA, 0xFE]))
    }
}
