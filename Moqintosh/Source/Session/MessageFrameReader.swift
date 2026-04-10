//
//  MessageFrameReader.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// Reassembles MOQT message frames from a raw byte stream.
///
/// MOQT frames arrive over QUIC streams in arbitrary chunk sizes —
/// a single `receive` call may contain a partial frame, exactly one frame,
/// or multiple frames concatenated together.
/// `MessageFrameReader` maintains an internal buffer and calls ``read(from:)``
/// repeatedly until a complete frame is available, then returns it.
///
/// Frame wire format (per draft-ietf-moq-transport §8):
/// ```
/// +---------------+
/// | Type   (i)    |  variable-length integer (1–8 bytes, RFC 9000 §16)
/// +---------------+
/// | Length (16)   |  unsigned 16-bit big-endian, byte length of Payload
/// +---------------+
/// | Payload (…)   |  `Length` bytes
/// +---------------+
/// ```
///
/// ### Usage
/// ```swift
/// let reader = MessageFrameReader()
/// let message = try await reader.read(from: stream)
/// ```
final class MessageFrameReader {

    private var buffer: Data = .init()

    /// Reads exactly one complete MOQT frame from `stream` and returns the decoded message.
    ///
    /// 1. Reads raw chunks into the buffer until a full frame is available.
    /// 2. Decodes the message type (varint) and length (16-bit BE).
    /// 3. If the payload is incomplete, fetches more data and retries from step 1.
    /// 4. Decodes the payload according to the message type.
    /// 5. Wraps the result in ``MOQTMessage`` and returns it.
    ///
    /// - Parameter stream: The bidirectional transport stream to read from.
    /// - Returns: The next decoded ``MOQTMessage``.
    func read(from stream: any TransportBiStream) async throws -> MOQTMessage {
        while true {
            if let message = try extractMessage() {
                return message
            }
            buffer.append(try await stream.receive())
        }
    }

    // MARK: - Private

    /// Attempt to extract and decode one complete message from `buffer`.
    /// Returns `nil` if more data is needed without consuming any bytes.
    private func extractMessage() throws -> MOQTMessage? {
        var offset: Int = 0

        // 1. Decode Type (varint)
        guard let rawType = try? buffer.readVarint(at: &offset) else { return nil }
        let type = UInt64(rawType)

        // 2. Decode Length (16-bit big-endian)
        guard offset + 2 <= buffer.count else { return nil }
        let high = UInt16(buffer[buffer.startIndex + offset])
        let low  = UInt16(buffer[buffer.startIndex + offset + 1])
        let payloadLength = Int((high << 8) | low)
        offset += 2

        // 3. Wait until the full payload has arrived
        guard offset + payloadLength <= buffer.count else { return nil }

        // 4. Extract payload and advance buffer
        let payload = Data(buffer[buffer.startIndex + offset ..< buffer.startIndex + offset + payloadLength])
        buffer = Data(buffer[(buffer.startIndex + offset + payloadLength)...])

        // 5. Decode according to message type and wrap in MOQTMessage
        switch MessageType(rawValue: type) {
        case .clientSetup:
            return .clientSetup(try ClientSetupMessage.decode(type: type, payload: payload))
        case .serverSetup:
            return .serverSetup(try ServerSetupMessage.decode(type: type, payload: payload))
        default:
            return .unknown(type: type, payload: payload)
        }
    }
}
