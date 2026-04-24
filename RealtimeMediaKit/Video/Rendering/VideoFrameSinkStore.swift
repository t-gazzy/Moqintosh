//
//  VideoFrameSinkStore.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation
import Synchronization

// Safe because sink access is serialized by state.
final class VideoFrameSinkStore: @unchecked Sendable {
    private let state: Mutex<State>

    init(sink: (any VideoFrameSink)?) {
        self.state = Mutex<State>(State(sink: sink))
    }

    func sink() -> (any VideoFrameSink)? {
        state.withLock { state in
            state.sink
        }
    }

    func attach(_ sink: any VideoFrameSink) {
        state.withLock { state in
            state.sink = sink
        }
    }

    func detach() {
        state.withLock { state in
            state.sink = nil
        }
    }
}

extension VideoFrameSinkStore {
    private struct State {
        var sink: (any VideoFrameSink)?

        init(sink: (any VideoFrameSink)?) {
            self.sink = sink
        }
    }
}
