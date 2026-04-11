//
//  SessionRequestStore.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

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
        case trackStatus(CheckedContinuation<TrackStatus, Error>)
    }

    private let stateQueue: DispatchQueue
    private var requests: [UInt64: PendingRequest]

    init() {
        self.stateQueue = .init(label: "Moqintosh.SessionRequestStore")
        self.requests = [:]
    }

    func addRequest(_ id: UInt64, continuation: CheckedContinuation<Void, Error>) {
        stateQueue.sync {
            requests[id] = .namespace(continuation)
        }
    }

    func addPublishRequest(
        _ id: UInt64,
        publishedTrack: PublishedTrack,
        continuation: CheckedContinuation<PublishedTrack, Error>
    ) {
        stateQueue.sync {
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
        stateQueue.sync {
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
        stateQueue.sync {
            requests[id] = .trackStatus(continuation)
        }
    }

    func resolveRequest(with message: PublishNamespaceOKMessage) {
        let request: PendingRequest? = stateQueue.sync {
            requests.removeValue(forKey: message.requestID)
        }
        guard case .namespace(let continuation) = request else { return }
        continuation.resume()
    }

    func rejectRequest(with message: PublishNamespaceErrorMessage) {
        let request: PendingRequest? = stateQueue.sync {
            requests.removeValue(forKey: message.requestID)
        }
        guard case .namespace(let continuation) = request else { return }
        continuation.resume(throwing: PublishNamespaceError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    func failRequest(_ id: UInt64, error: any Error) {
        let request: PendingRequest? = stateQueue.sync {
            requests.removeValue(forKey: id)
        }
        guard case .namespace(let continuation) = request else { return }
        continuation.resume(throwing: error)
    }

    func resolvePublishRequest(with message: PublishOKMessage) {
        let request: PendingRequest? = stateQueue.sync {
            requests.removeValue(forKey: message.requestID)
        }
        guard case .publish(let publishedTrack, let continuation) = request else { return }
        continuation.resume(returning: publishedTrack)
    }

    func rejectPublishRequest(with message: PublishErrorMessage) {
        let request: PendingRequest? = stateQueue.sync {
            requests.removeValue(forKey: message.requestID)
        }
        guard case .publish(_, let continuation) = request else { return }
        continuation.resume(throwing: PublishError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    func failPublishRequest(_ id: UInt64, error: any Error) {
        let request: PendingRequest? = stateQueue.sync {
            requests.removeValue(forKey: id)
        }
        guard case .publish(_, let continuation) = request else { return }
        continuation.resume(throwing: error)
    }

    func resolveRequest(with message: SubscribeNamespaceOKMessage) {
        let request: PendingRequest? = stateQueue.sync {
            requests.removeValue(forKey: message.requestID)
        }
        guard case .namespace(let continuation) = request else { return }
        continuation.resume()
    }

    func rejectRequest(with message: SubscribeNamespaceErrorMessage) {
        let request: PendingRequest? = stateQueue.sync {
            requests.removeValue(forKey: message.requestID)
        }
        guard case .namespace(let continuation) = request else { return }
        continuation.resume(throwing: SubscribeNamespaceError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    func resolveSubscribeRequest(with message: SubscribeOKMessage) {
        let request: PendingRequest? = stateQueue.sync {
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
        let publishedTrack: PublishedTrack = .init(
            requestID: message.requestID,
            resource: resource,
            trackAlias: message.trackAlias,
            groupOrder: message.groupOrder,
            contentExist: message.contentExist,
            forward: forward
        )
        let subscription: Subscription = .init(
            requestID: message.requestID,
            publishedTrack: publishedTrack,
            expires: message.expires,
            subscriberPriority: subscriberPriority,
            filter: filter
        )
        continuation.resume(returning: subscription)
    }

    func rejectSubscribeRequest(with message: SubscribeErrorMessage) {
        let request: PendingRequest? = stateQueue.sync {
            requests.removeValue(forKey: message.requestID)
        }
        guard case .subscribe(_, _, _, _, _, let continuation) = request else { return }
        continuation.resume(throwing: SubscribeError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    func failSubscribeRequest(_ id: UInt64, error: any Error) {
        let request: PendingRequest? = stateQueue.sync {
            requests.removeValue(forKey: id)
        }
        guard case .subscribe(_, _, _, _, _, let continuation) = request else { return }
        continuation.resume(throwing: error)
    }

    func resolveTrackStatusRequest(with message: TrackStatusOKMessage) {
        let request: PendingRequest? = stateQueue.sync {
            requests.removeValue(forKey: message.requestID)
        }
        guard case .trackStatus(let continuation) = request else { return }
        continuation.resume(returning: message.trackStatus)
    }

    func rejectTrackStatusRequest(with message: TrackStatusErrorMessage) {
        let request: PendingRequest? = stateQueue.sync {
            requests.removeValue(forKey: message.requestID)
        }
        guard case .trackStatus(let continuation) = request else { return }
        continuation.resume(throwing: TrackStatusError.rejected(code: message.errorCode, reason: message.reasonPhrase))
    }

    func failTrackStatusRequest(_ id: UInt64, error: any Error) {
        let request: PendingRequest? = stateQueue.sync {
            requests.removeValue(forKey: id)
        }
        guard case .trackStatus(let continuation) = request else { return }
        continuation.resume(throwing: error)
    }
}
