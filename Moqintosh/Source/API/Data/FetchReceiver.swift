//
//  FetchReceiver.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/12.
//

import Foundation

// Safe because receiveTask is the only concurrent execution context and object delivery happens through AsyncThrowingStream.
/// Receives subgroup objects from an accepted fetch stream.
public final class FetchReceiver: @unchecked Sendable {

    /// The objects received from this fetch stream.
    public let objects: AsyncThrowingStream<SubgroupObject, Error>
    /// The accepted fetch subscription associated with this receiver.
    public let fetchSubscription: FetchSubscription

    private let stream: TransportUniReceiveStream
    private let initialData: Data
    private let objectContinuation: AsyncThrowingStream<SubgroupObject, Error>.Continuation
    private var receiveTask: Task<Void, Never>?
    var onClose: (@Sendable (FetchReceiver) async -> Void)?

    init(stream: TransportUniReceiveStream, fetchSubscription: FetchSubscription, initialData: Data) {
        let objectStream: (
            stream: AsyncThrowingStream<SubgroupObject, Error>,
            continuation: AsyncThrowingStream<SubgroupObject, Error>.Continuation
        ) = FetchReceiver.makeObjectStream()
        self.objects = objectStream.stream
        self.stream = stream
        self.fetchSubscription = fetchSubscription
        self.initialData = initialData
        self.objectContinuation = objectStream.continuation
        self.receiveTask = nil
        self.onClose = nil
    }

    deinit {
        receiveTask?.cancel()
        objectContinuation.finish()
    }

    func start() {
        precondition(receiveTask == nil, "FetchReceiver.start() must only be called once")
        receiveTask = Task { [stream, initialData, objectContinuation] in
            let frameReader: FetchObjectFrameReader = FetchObjectFrameReader(initialData: initialData)
            do {
                while !Task.isCancelled {
                    let object: SubgroupObject = try await frameReader.read(from: stream)
                    objectContinuation.yield(object)
                }
            } catch is CancellationError {
                objectContinuation.finish()
            } catch StreamReceiveCompletionError.closed {
                objectContinuation.finish()
            } catch {
                OSLogger.debug("Fetch receive loop ended: \(error)")
                objectContinuation.finish(throwing: error)
            }
            await self.onClose?(self)
        }
    }

    func stop() {
        receiveTask?.cancel()
        receiveTask = nil
        objectContinuation.finish()
    }

    private static func makeObjectStream() -> (
        stream: AsyncThrowingStream<SubgroupObject, Error>,
        continuation: AsyncThrowingStream<SubgroupObject, Error>.Continuation
    ) {
        var streamContinuation: AsyncThrowingStream<SubgroupObject, Error>.Continuation?
        let stream: AsyncThrowingStream<SubgroupObject, Error> = AsyncThrowingStream<SubgroupObject, Error> { continuation in
            streamContinuation = continuation
        }
        guard let streamContinuation else {
            preconditionFailure("AsyncThrowingStream must create a continuation")
        }
        return (stream, streamContinuation)
    }
}
