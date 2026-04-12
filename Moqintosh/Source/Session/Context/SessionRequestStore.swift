//
//  SessionRequestStore.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation
import Synchronization

final class SessionRequestStore {

    private enum PendingRequest {
        case namespace(CheckedContinuation<Void, Error>)
        case publish(
            publishedTrack: PublishedTrack,
            continuation: CheckedContinuation<PublishedTrack, Error>
        )
        case subscribe(
            resource: TrackResource,
            subscriberPriority: UInt8,
            requestedGroupOrder: GroupOrder,
            forward: Bool,
            filter: SubscriptionFilter,
            continuation: CheckedContinuation<Subscription, Error>
        )
        case fetch(
            resource: TrackResource,
            subscriberPriority: UInt8,
            continuation: CheckedContinuation<FetchSubscription, Error>
        )
        case trackStatus(CheckedContinuation<TrackStatus, Error>)
    }

    private let requests: Mutex<[UInt64: PendingRequest]>

    init() {
        self.requests = Mutex<[UInt64: PendingRequest]>([:])
    }

    func addRequest(_ id: UInt64, continuation: CheckedContinuation<Void, Error>) {
        requests.withLock { requests in
            requests[id] = .namespace(continuation)
        }
    }

    func addPublishRequest(
        _ id: UInt64,
        publishedTrack: PublishedTrack,
        continuation: CheckedContinuation<PublishedTrack, Error>
    ) {
        requests.withLock { requests in
            requests[id] = .publish(publishedTrack: publishedTrack, continuation: continuation)
        }
    }

    func addSubscribeRequest(
        _ id: UInt64,
        resource: TrackResource,
        subscriberPriority: UInt8,
        requestedGroupOrder: GroupOrder,
        forward: Bool,
        filter: SubscriptionFilter,
        continuation: CheckedContinuation<Subscription, Error>
    ) {
        requests.withLock { requests in
            requests[id] = .subscribe(
                resource: resource,
                subscriberPriority: subscriberPriority,
                requestedGroupOrder: requestedGroupOrder,
                forward: forward,
                filter: filter,
                continuation: continuation
            )
        }
    }

    func addTrackStatusRequest(_ id: UInt64, continuation: CheckedContinuation<TrackStatus, Error>) {
        requests.withLock { requests in
            requests[id] = .trackStatus(continuation)
        }
    }

    func addFetchRequest(
        _ id: UInt64,
        resource: TrackResource,
        subscriberPriority: UInt8,
        continuation: CheckedContinuation<FetchSubscription, Error>
    ) {
        requests.withLock { requests in
            requests[id] = .fetch(
                resource: resource,
                subscriberPriority: subscriberPriority,
                continuation: continuation
            )
        }
    }

    func resolveRequest(with message: PublishNamespaceOKMessage) {
        let request: PendingRequest? = requests.withLock { requests in
            requests.removeValue(forKey: message.requestID)
        }
        guard case .namespace(let continuation) = request else { return }
        continuation.resume()
    }

    func rejectRequest(with message: PublishNamespaceErrorMessage) {
        let request: PendingRequest? = requests.withLock { requests in
            requests.removeValue(forKey: message.requestID)
        }
        guard case .namespace(let continuation) = request else { return }
        continuation.resume(throwing: PublishNamespaceError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    func failRequest(_ id: UInt64, error: any Error) {
        let request: PendingRequest? = requests.withLock { requests in
            requests.removeValue(forKey: id)
        }
        guard case .namespace(let continuation) = request else { return }
        continuation.resume(throwing: error)
    }

    func resolvePublishRequest(with message: PublishOKMessage) {
        let request: PendingRequest? = requests.withLock { requests in
            requests.removeValue(forKey: message.requestID)
        }
        guard case .publish(let publishedTrack, let continuation) = request else { return }
        continuation.resume(returning: publishedTrack)
    }

    func rejectPublishRequest(with message: PublishErrorMessage) {
        let request: PendingRequest? = requests.withLock { requests in
            requests.removeValue(forKey: message.requestID)
        }
        guard case .publish(_, let continuation) = request else { return }
        continuation.resume(throwing: PublishError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    func failPublishRequest(_ id: UInt64, error: any Error) {
        let request: PendingRequest? = requests.withLock { requests in
            requests.removeValue(forKey: id)
        }
        guard case .publish(_, let continuation) = request else { return }
        continuation.resume(throwing: error)
    }

    func resolveRequest(with message: SubscribeNamespaceOKMessage) {
        let request: PendingRequest? = requests.withLock { requests in
            requests.removeValue(forKey: message.requestID)
        }
        guard case .namespace(let continuation) = request else { return }
        continuation.resume()
    }

    func rejectRequest(with message: SubscribeNamespaceErrorMessage) {
        let request: PendingRequest? = requests.withLock { requests in
            requests.removeValue(forKey: message.requestID)
        }
        guard case .namespace(let continuation) = request else { return }
        continuation.resume(throwing: SubscribeNamespaceError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    func resolveSubscribeRequest(with message: SubscribeOKMessage) {
        let request: PendingRequest? = requests.withLock { requests in
            requests.removeValue(forKey: message.requestID)
        }
        guard case .subscribe(
            let resource,
            let subscriberPriority,
            _,
            let forward,
            let filter,
            let continuation
        ) = request else { return }
        let publishedTrack: PublishedTrack = PublishedTrack(
            requestID: message.requestID,
            resource: resource,
            trackAlias: message.trackAlias,
            groupOrder: message.groupOrder,
            contentExist: message.contentExist,
            forward: forward
        )
        let subscription: Subscription = Subscription(
            requestID: message.requestID,
            publishedTrack: publishedTrack,
            expires: message.expires,
            subscriberPriority: subscriberPriority,
            filter: filter
        )
        continuation.resume(returning: subscription)
    }

    func rejectSubscribeRequest(with message: SubscribeErrorMessage) {
        let request: PendingRequest? = requests.withLock { requests in
            requests.removeValue(forKey: message.requestID)
        }
        guard case .subscribe(_, _, _, _, _, let continuation) = request else { return }
        continuation.resume(throwing: SubscribeError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    func failSubscribeRequest(_ id: UInt64, error: any Error) {
        let request: PendingRequest? = requests.withLock { requests in
            requests.removeValue(forKey: id)
        }
        guard case .subscribe(_, _, _, _, _, let continuation) = request else { return }
        continuation.resume(throwing: error)
    }

    func resolveTrackStatusRequest(with message: TrackStatusOKMessage) {
        let request: PendingRequest? = requests.withLock { requests in
            requests.removeValue(forKey: message.requestID)
        }
        guard case .trackStatus(let continuation) = request else { return }
        continuation.resume(returning: message.trackStatus)
    }

    func rejectTrackStatusRequest(with message: TrackStatusErrorMessage) {
        let request: PendingRequest? = requests.withLock { requests in
            requests.removeValue(forKey: message.requestID)
        }
        guard case .trackStatus(let continuation) = request else { return }
        continuation.resume(throwing: TrackStatusError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    func failTrackStatusRequest(_ id: UInt64, error: any Error) {
        let request: PendingRequest? = requests.withLock { requests in
            requests.removeValue(forKey: id)
        }
        guard case .trackStatus(let continuation) = request else { return }
        continuation.resume(throwing: error)
    }

    func resolveFetchRequest(with message: FetchOKMessage) {
        let request: PendingRequest? = requests.withLock { requests in
            requests.removeValue(forKey: message.requestID)
        }
        guard case .fetch(let resource, let subscriberPriority, let continuation) = request else { return }
        let fetchSubscription: FetchSubscription = FetchSubscription(
            requestID: message.requestID,
            resource: resource,
            subscriberPriority: subscriberPriority,
            groupOrder: message.groupOrder,
            endOfTrack: message.endOfTrack,
            endLocation: message.endLocation,
            maxCacheDuration: message.maxCacheDuration
        )
        continuation.resume(returning: fetchSubscription)
    }

    func rejectFetchRequest(with message: FetchErrorMessage) {
        let request: PendingRequest? = requests.withLock { requests in
            requests.removeValue(forKey: message.requestID)
        }
        guard case .fetch(_, _, let continuation) = request else { return }
        continuation.resume(throwing: FetchError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    func failFetchRequest(_ id: UInt64, error: any Error) {
        let request: PendingRequest? = requests.withLock { requests in
            requests.removeValue(forKey: id)
        }
        guard case .fetch(_, _, let continuation) = request else { return }
        continuation.resume(throwing: error)
    }
}
