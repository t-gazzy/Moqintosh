//
//  ContentExistTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Testing
@testable import Moqintosh

struct ContentExistTests {

    @Test func roundTripNoContent() throws {
        let decoded: ContentExist = try .decode(from: .init(data: ContentExist.noContent.encode()))
        guard case .noContent = decoded else {
            Issue.record("Expected noContent")
            return
        }
    }

    @Test func roundTripExists() throws {
        let encoded: Data = ContentExist.exists(.init(group: 1, object: 2)).encode()
        let decoded: ContentExist = try .decode(from: .init(data: encoded))
        guard case .exists(let location) = decoded else {
            Issue.record("Expected exists")
            return
        }
        #expect(location.group == 1)
        #expect(location.object == 2)
    }
}
