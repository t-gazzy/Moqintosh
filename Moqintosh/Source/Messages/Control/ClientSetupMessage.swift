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

    static let type: MessageType = .clientSetup

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
        message.writeVarint(ClientSetupMessage.type.rawValue)
        // Length is 16-bit big-endian
        let length = UInt16(payload.count)
        message.append(UInt8(length >> 8))
        message.append(UInt8(length & 0xFF))
        message.append(payload)
        return message
    }

    // MARK: - Decode

    /// Decodes a `ClientSetupMessage` from a payload ``ByteReader``.
    /// The frame header (Type + Length) must have already been consumed by the caller.
    static func decode(from payload: Data) throws -> ClientSetupMessage {
        let reader = ByteReader(data: payload)

        let versionCount = Int(try reader.readVarint())
        var versions: [UInt32] = []
        for _ in 0 ..< versionCount {
            versions.append(UInt32(try reader.readVarint()))
        }

        let paramCount = Int(try reader.readVarint())
        var params: [SetupParameter] = []
        for _ in 0 ..< paramCount {
            if let param = try? SetupParameter.decode(from: reader) {
                params.append(param)
            }
        }

        return ClientSetupMessage(supportedVersions: versions, parameters: params)
    }
}
