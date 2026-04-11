//
//  ControlMessageChannel.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

protocol ControlMessageChannel: AnyObject {
    func issueRequestID() async throws -> UInt64
    func issueTrackAlias() -> UInt64
    func sendControlMessage(bytes: Data) async throws
    func performPublishNamespaceRequest(requestID: UInt64, bytes: Data) async throws
    func performPublishRequest(requestID: UInt64, publishedTrack: PublishedTrack, bytes: Data) async throws -> PublishedTrack
    func performSubscribeNamespaceRequest(requestID: UInt64, bytes: Data) async throws
    func performSubscribeRequest(
        requestID: UInt64,
        resource: TrackResource,
        subscriberPriority: UInt8,
        requestedGroupOrder: GroupOrder,
        forward: Bool,
        filter: SubscriptionFilter,
        bytes: Data
    ) async throws -> Subscription
    func performTrackStatusRequest(requestID: UInt64, bytes: Data) async throws -> TrackStatus
}
