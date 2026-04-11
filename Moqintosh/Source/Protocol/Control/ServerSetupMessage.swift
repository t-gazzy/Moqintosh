//
//  ServerSetupMessage.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// MOQT SERVER_SETUP message (Section 9.3, Type = 0x21)
///
/// Wire format:
/// ```
/// SERVER_SETUP {
///   Type (i) = 0x21,
///   Length (16),
///   Selected Version (i),
///   Number of Parameters (i),
///   Setup Parameters (..) ...,
/// }
/// ```
struct ServerSetupMessage {

    static let type: MessageType = .serverSetup

    let selectedVersion: UInt32
    let parameters: [SetupParameter]

    // MARK: - Encode

    func encode() -> Data {
        var payload = Data()

        payload.writeVarint(UInt64(selectedVersion))

        payload.writeVarint(UInt64(parameters.count))
        for parameter in parameters {
            payload.append(parameter.encode())
        }

        var message = Data()
        message.writeVarint(ServerSetupMessage.type.rawValue)
        let length = UInt16(payload.count)
        message.append(UInt8(length >> 8))
        message.append(UInt8(length & 0xFF))
        message.append(payload)
        return message
    }

    // MARK: - Decode

    /// Decodes a `ServerSetupMessage` from a payload ``ByteReader``.
    /// The frame header (Type + Length) must have already been consumed by the caller.
    static func decode(from payload: Data) throws -> ServerSetupMessage {
        let reader = ByteReader(data: payload)

        let version = UInt32(try reader.readVarint())

        let paramCount = Int(try reader.readVarint())
        var params: [SetupParameter] = []
        for _ in 0 ..< paramCount {
            if let param = try? SetupParameter.decode(from: reader) {
                params.append(param)
            }
        }

        return ServerSetupMessage(selectedVersion: version, parameters: params)
    }
}
