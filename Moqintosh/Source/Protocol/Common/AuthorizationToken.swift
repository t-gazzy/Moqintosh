//
//  AuthorizationToken.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Raw authorization token bytes carried by MOQT AUTHORIZATION TOKEN parameters.
public struct AuthorizationToken {

    public let value: Data

    public init(value: Data) {
        self.value = value
    }
}
