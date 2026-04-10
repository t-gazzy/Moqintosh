//
//  SubscriptionFilter.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

public enum SubscriptionFilter {
    case nextGroupStart
    case largestObject
    case absoluteStart(Location)
    case absoluteRange(start: Location, endGroup: UInt64)
}
