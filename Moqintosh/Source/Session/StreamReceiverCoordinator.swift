//
//  StreamReceiverCoordinator.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

final class StreamReceiverCoordinator: TransportConnectionDelegate {

    private let sessionContext: SessionContext

    init(sessionContext: SessionContext) {
        self.sessionContext = sessionContext
    }

    func connection(_ connection: TransportConnection, didReceiveUniStream stream: TransportUniReceiveStream) {
        Task {
            do {
                let (header, initialData): (SubgroupHeader, Data) = try await readHeader(from: stream)
                guard let handler: StreamReceiverStore.Handler = sessionContext.streamReceiverStore.handler(for: header.trackAlias) else {
                    OSLogger.warn("No stream receiver registered for track alias \(header.trackAlias)")
                    return
                }
                handler(stream, header, initialData)
            } catch {
                OSLogger.error("Failed to receive subgroup stream header: \(error)")
            }
        }
    }

    func connection(_ connection: TransportConnection, didReceiveDatagram bytes: Data) {
        do {
            let datagram: ObjectDatagram = try .decode(bytes)
            guard let handler: DatagramReceiverStore.Handler = sessionContext.datagramReceiverStore.handler(for: datagram.trackAlias) else {
                OSLogger.warn("No datagram receiver registered for track alias \(datagram.trackAlias)")
                return
            }
            handler(datagram)
        } catch {
            OSLogger.error("Failed to decode OBJECT_DATAGRAM: \(error)")
        }
    }

    private func readHeader(from stream: TransportUniReceiveStream) async throws -> (SubgroupHeader, Data) {
        var buffer: Data = .init()
        while true {
            do {
                let reader: ByteReader = .init(data: buffer)
                let header: SubgroupHeader = try .decode(from: reader)
                let consumedBytes: Int = buffer.count - reader.remainingCount
                let remainingBytes: Data = Data(buffer.dropFirst(consumedBytes))
                return (header, remainingBytes)
            } catch ByteReaderError.insufficientData {
                let result: TransportUniReceiveResult = try await stream.receive()
                buffer.append(result.bytes)
                if result.isComplete && buffer.isEmpty {
                    throw StreamReceiveCompletionError.closed
                }
            }
        }
    }
}
