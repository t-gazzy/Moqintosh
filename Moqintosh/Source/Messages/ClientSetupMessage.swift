//
//  ClientSetupMessage.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

import Foundation

/// MOQT CLIENT_SETUP message (Section 9.3, Type = 0x20)
///
/// Wire format:
/// ```
/// CLIENT_SETUP {
///   Type (i) = 0x20,
///   Length (16),
///   Number of Supported Versions (i),
///   Supported Versions (i) ...,
///   Number of Parameters (i),
///   Setup Parameters (..) ...,
/// }
/// ```
struct ClientSetupMessage {

    static let type: UInt64 = 0x20

    let supportedVersions: [UInt32]
    let parameters: [SetupParameter]

    // MARK: - Encode

    func encode() -> Data {
        var payload = Data()

        payload.writeVarint(UInt64(supportedVersions.count))
        for version in supportedVersions {
            payload.writeVarint(UInt64(version))
        }

        payload.writeVarint(UInt64(parameters.count))
        for parameter in parameters {
            payload.append(parameter.encode())
        }

        var message = Data()
        message.writeVarint(ClientSetupMessage.type)
        // Length is 16-bit big-endian
        let length = UInt16(payload.count)
        message.append(UInt8(length >> 8))
        message.append(UInt8(length & 0xFF))
        message.append(payload)
        return message
    }

    // MARK: - Decode

    static func decode(from data: Data) throws -> ClientSetupMessage {
        var offset: Int = 0

        let type: Int = try data.readVarint(at: &offset)
        guard type == ClientSetupMessage.type else {
            throw ClientSetupMessageError.unexpectedType(UInt64(type))
        }

        // Length (16-bit big-endian)
        guard offset + 2 <= data.count else {
            throw DataReadError.insufficientData(requested: 2, available: data.count - offset)
        }
        offset += 2 // Length field is informational; payload follows immediately

        let versionCount: Int = try data.readVarint(at: &offset)
        var versions: [UInt32] = []
        for _ in 0 ..< versionCount {
            let v: Int = try data.readVarint(at: &offset)
            versions.append(UInt32(v))
        }

        let paramCount: Int = try data.readVarint(at: &offset)
        var params: [SetupParameter] = []
        for _ in 0 ..< paramCount {
            if let param = try? SetupParameter.decode(from: data, at: &offset) {
                params.append(param)
            }
        }

        return ClientSetupMessage(supportedVersions: versions, parameters: params)
    }
}

enum ClientSetupMessageError: Error {
    case unexpectedType(UInt64)
}
