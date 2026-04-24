//
//  AudioFrameSinkStore.swift
//  RealtimeMediaKit
//
//  Created by Codex on 2026/04/22.
//

import Foundation
import Synchronization

// Safe because sink access is serialized by state.
final class AudioFrameSinkStore: @unchecked Sendable {
    private let state: Mutex<State>

    init(sink: (any AudioFrameSink)?) {
        self.state = Mutex<State>(State(sink: sink))
    }

    func sink() -> (any AudioFrameSink)? {
        state.withLock { state in
            state.sink
        }
    }

    func attach(_ sink: any AudioFrameSink) {
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

extension AudioFrameSinkStore {
    private struct State {
        var sink: (any AudioFrameSink)?

        init(sink: (any AudioFrameSink)?) {
            self.sink = sink
        }
    }
}
