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

    static let type: UInt64 = 0x21

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
        message.writeVarint(ServerSetupMessage.type)
        let length = UInt16(payload.count)
        message.append(UInt8(length >> 8))
        message.append(UInt8(length & 0xFF))
        message.append(payload)
        return message
    }

    // MARK: - Decode

    static func decode(from data: Data) throws -> ServerSetupMessage {
        var offset: Int = 0

        let type: Int = try data.readVarint(at: &offset)
        guard type == ServerSetupMessage.type else {
            throw ServerSetupMessageError.unexpectedType(UInt64(type))
        }

        // Length (16-bit big-endian)
        guard offset + 2 <= data.count else {
            throw DataReadError.insufficientData(requested: 2, available: data.count - offset)
        }
        offset += 2

        let version: Int = try data.readVarint(at: &offset)

        let paramCount: Int = try data.readVarint(at: &offset)
        var params: [SetupParameter] = []
        for _ in 0 ..< paramCount {
            if let param = try? SetupParameter.decode(from: data, at: &offset) {
                params.append(param)
            }
        }

        return ServerSetupMessage(selectedVersion: UInt32(version), parameters: params)
    }
}

enum ServerSetupMessageError: Error {
    case unexpectedType(UInt64)
}
