//
//  SubscriptionFilter.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

public enum SubscriptionFilter {
    case nextGroupStart
    case largestObject
    case absoluteStart(Location)
    case absoluteRange(start: Location, endGroup: UInt64)

    func encode() -> Data {
        var data: Data = .init()
        switch self {
        case .nextGroupStart:
            data.writeVarint(0x01)
        case .largestObject:
            data.writeVarint(0x02)
        case .absoluteStart(let location):
            data.writeVarint(0x03)
            data.append(location.encode())
        case .absoluteRange(let start, let endGroup):
            data.writeVarint(0x04)
            data.append(start.encode())
            data.writeVarint(endGroup)
        }
        return data
    }

    static func decode(from reader: ByteReader) throws -> SubscriptionFilter {
        let filterType: UInt64 = try reader.readVarint()
        switch filterType {
        case 0x01:
            return .nextGroupStart
        case 0x02:
            return .largestObject
        case 0x03:
            return .absoluteStart(try .decode(from: reader))
        case 0x04:
            let start: Location = try .decode(from: reader)
            let endGroup: UInt64 = try reader.readVarint()
            return .absoluteRange(start: start, endGroup: endGroup)
        default:
            throw SubscriptionFilterError.invalidType(filterType)
        }
    }
}

enum SubscriptionFilterError: Error {
    case invalidType(UInt64)
}
