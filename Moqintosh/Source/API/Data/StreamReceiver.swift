//
//  StreamReceiver.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

// Safe because receiveTask is the only concurrent execution context and delegate callbacks run on that task.
/// Receives subgroup objects for a subscribed track.
public final class StreamReceiver: @unchecked Sendable {

    /// The objects received from this stream.
    public let objects: AsyncThrowingStream<SubgroupObject, Error>
    /// The subgroup header associated with this receive stream.
    public let header: SubgroupHeader

    private let stream: TransportUniReceiveStream
    private let subscription: Subscription
    private let initialData: Data
    private let objectContinuation: AsyncThrowingStream<SubgroupObject, Error>.Continuation
    private var receiveTask: Task<Void, Never>?
    var onClose: (@Sendable (StreamReceiver) async -> Void)?

    init(stream: TransportUniReceiveStream, subscription: Subscription, header: SubgroupHeader, initialData: Data) {
        let objectStream: (
            stream: AsyncThrowingStream<SubgroupObject, Error>,
            continuation: AsyncThrowingStream<SubgroupObject, Error>.Continuation
        ) = StreamReceiver.makeObjectStream()
        self.objects = objectStream.stream
        self.stream = stream
        self.subscription = subscription
        self.header = header
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
        precondition(receiveTask == nil, "StreamReceiver.start() must only be called once")
        receiveTask = Task { [stream, header, initialData, objectContinuation] in
            let frameReader: SubgroupObjectFrameReader = SubgroupObjectFrameReader(header: header, initialData: initialData)
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
                OSLogger.debug("Stream receive loop ended: \(error)")
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
