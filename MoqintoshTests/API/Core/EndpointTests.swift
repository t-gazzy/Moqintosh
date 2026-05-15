//
//  EndpointTests.swift
//  MoqintoshTests
//
//  Created by Codex on 2026/05/15.
//

import Foundation
import Testing
@testable import Moqintosh

struct EndpointTests {

    @Test func initAcceptsMoqtURL() throws {
        let url: URL = try #require(URL(string: "moqt://example.com:4433"))

        let endpoint: Endpoint = try #require(Endpoint(url: url))

        #expect(endpoint.url == url)
        #expect(endpoint.host == "example.com")
        #expect(endpoint.port == 4433)
    }

    @Test func initRejectsNonMoqtURL() throws {
        let url: URL = try #require(URL(string: "https://example.com:4433"))

        #expect(Endpoint(url: url) == nil)
    }

    @Test func initRejectsURLWithoutHost() throws {
        let url: URL = try #require(URL(string: "moqt:///track"))

        #expect(Endpoint(url: url) == nil)
    }

    @Test func initRejectsURLWithoutPort() throws {
        let url: URL = try #require(URL(string: "moqt://example.com"))

        #expect(Endpoint(url: url) == nil)
    }
}
