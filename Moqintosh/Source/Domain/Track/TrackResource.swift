//
//  TrackResource.swift
//  Moqintosh
//
//  Created by Codex on 2026/04/10.
//

import Foundation

/// Identifies a track that can be subscribed to or published.
public struct TrackResource: Sendable {

    /// The namespace that owns the track.
    public let trackNamespace: TrackNamespace
    /// The binary track name within the namespace.
    public let trackName: Data
    /// The optional authorization token attached to the resource.
    public let authorizationToken: AuthorizationToken?

    /// Creates a track resource.
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
