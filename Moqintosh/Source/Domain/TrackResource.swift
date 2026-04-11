//
//  TrackResource.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Identifies a track that can be subscribed to or published.
public struct TrackResource {

    public let trackNamespace: TrackNamespace
    public let trackName: Data
    public let authorizationToken: AuthorizationToken?

    public init(
        trackNamespace: TrackNamespace,
        trackName: Data,
        authorizationToken: AuthorizationToken? = nil
    ) {
        self.trackNamespace = trackNamespace
        self.trackName = trackName
        self.authorizationToken = authorizationToken
    }
}
