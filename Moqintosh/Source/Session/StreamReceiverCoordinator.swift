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
                let header: StreamHeader = try await readHeader(from: stream)
                switch header {
                case .subgroup(let subgroupHeader, let initialData):
                    guard let handler: StreamReceiverStore.Handler = sessionContext.streamReceiverStore.handler(for: subgroupHeader.trackAlias) else {
                        OSLogger.warn("No stream receiver registered for track alias \(subgroupHeader.trackAlias)")
                        return
                    }
                    handler(stream, subgroupHeader, initialData)
                case .fetch(let fetchHeader, let initialData):
                    guard let handler: FetchReceiverStore.Handler = sessionContext.fetchReceiverStore.handler(for: fetchHeader.requestID) else {
                        OSLogger.warn("No fetch receiver registered for request ID \(fetchHeader.requestID)")
                        return
                    }
                    handler(stream, fetchHeader, initialData)
                }
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

    private func readHeader(from stream: TransportUniReceiveStream) async throws -> StreamHeader {
        var buffer: Data = Data()
        while true {
            do {
                let reader: ByteReader = ByteReader(data: buffer)
                let type: UInt64 = try reader.readVarint()
                let headerReader: ByteReader = ByteReader(data: buffer)
                if type == FetchHeader.type {
                    let header: FetchHeader = try .decode(from: headerReader)
                    let consumedBytes: Int = buffer.count - headerReader.remainingCount
                    let remainingBytes: Data = Data(buffer.dropFirst(consumedBytes))
                    return .fetch(header: header, initialData: remainingBytes)
                }
                let header: SubgroupHeader = try .decode(from: headerReader)
                let consumedBytes: Int = buffer.count - headerReader.remainingCount
                let remainingBytes: Data = Data(buffer.dropFirst(consumedBytes))
                return .subgroup(header: header, initialData: remainingBytes)
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

private enum StreamHeader {
    case subgroup(header: SubgroupHeader, initialData: Data)
    case fetch(header: FetchHeader, initialData: Data)
}
