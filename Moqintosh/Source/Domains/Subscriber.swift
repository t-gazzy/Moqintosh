//
//  Subscriber.swift
//  Moqintosh
//
//  Created by takemasa kaji on 2026/04/10.
//

/// Represents a MOQT subscriber created from a Session.
public final class Subscriber {

    public let session: Session

    init(session: Session) {
        self.session = session
    }
}
